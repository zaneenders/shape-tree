import Foundation
import Logging
import OpenAPIHummingbird
import OpenAPIRuntime
import ScribeCore
import ShapeTreeClient

// MARK: - APIProtocol implementation

/// Implements the generated `APIProtocol` produced by swift-openapi-generator.
/// Uses generated request/response types from the `ShapeTreeClient` module
/// so the client and server stay exactly in sync with `openapi.yaml`.
struct ShapeTreeHandler: APIProtocol, Sendable {

  let store: SessionStore
  let journalStore: JournalStore
  let log: Logger
  let defaultOllamaURL: String
  let agentModel: String
  let systemPrompt: String
  let bearerToken: String?
  let contextWindow: Int
  let contextWindowThreshold: Double
  let workingDirectory: String

  // MARK: - Error envelope helpers

  /// Single source of truth for the JSON body of every error response.
  private static func errorBody(_ message: String) -> Components.Schemas.HTTPErrorResponse {
    .init(error: .init(message: message))
  }

  /// Logs `event` and the underlying error, then returns the public 500 body. All non-domain
  /// failures funnel through this so the operator sees a structured log line for every 500.
  private func internalErrorBody(event: String, _ error: Error, public publicMessage: String)
    -> Components.Schemas.HTTPErrorResponse
  {
    log.error("event=\(event) error=\(error.localizedDescription)")
    return Self.errorBody(publicMessage)
  }

  // MARK: GET /journal/subjects

  func listJournalSubjects(
    _ input: Operations.listJournalSubjects.Input
  ) async throws -> Operations.listJournalSubjects.Output {
    do {
      let file = try await journalStore.loadSubjects()
      let response = Components.Schemas.JournalSubjectsResponse(subjects: Self.schemaSubjects(file))
      return .ok(.init(body: .json(response)))
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(
              event: "journal.subjects.failure",
              error,
              public: "Could not load journal subjects."))))
    }
  }

  // MARK: POST /journal/subjects

  func appendJournalSubject(
    _ input: Operations.appendJournalSubject.Input
  ) async throws -> Operations.appendJournalSubject.Output {
    guard case .json(let body) = input.body else {
      return .badRequest(.init(body: .json(Self.errorBody("Request body must be JSON."))))
    }

    do {
      let file = try await journalStore.appendSubject(rawLabel: body.subject)
      let response = Components.Schemas.JournalSubjectsResponse(subjects: Self.schemaSubjects(file))
      return .ok(.init(body: .json(response)))
    } catch JournalServiceError.emptySubjectLabel {
      return .badRequest(.init(body: .json(Self.errorBody(JournalServiceError.emptySubjectLabel.description))))
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(
              event: "journal.subjects.append.failure",
              error,
              public: "Failed to append journal subject."))))
    }
  }

  // MARK: GET /journal/entries

  func listJournalEntrySummaries(
    _ input: Operations.listJournalEntrySummaries.Input
  ) async throws -> Operations.listJournalEntrySummaries.Output {
    do {
      let rows = try await journalStore.listSummaries(
        startDayKey: input.query.start_date,
        endDayKey: input.query.end_date)
      let entries = rows.map {
        Components.Schemas.JournalEntrySummary(
          date: $0.dateKey,
          journal_relative_path: $0.journalRelativePath,
          word_count: $0.wordCount,
          line_count: $0.lineCount)
      }
      return .ok(.init(body: .json(.init(entries: entries))))
    } catch JournalQueryError.invalidJournalDayKey {
      return .badRequest(
        .init(
          body: .json(
            Self.errorBody("start_date and end_date must be formatted yy-MM-dd."))))
    } catch JournalQueryError.invalidRange {
      return .badRequest(
        .init(
          body: .json(
            Self.errorBody("start_date must be on or before end_date."))))
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(
              event: "journal.summaries.failure",
              error,
              public: "Failed to list journal entries."))))
    }
  }

  // MARK: GET /journal/entries/{journal_day}

  func getJournalEntryDetail(
    _ input: Operations.getJournalEntryDetail.Input
  ) async throws -> Operations.getJournalEntryDetail.Output {
    let dayKey = input.path.journal_day
    do {
      guard let detail = try await journalStore.entryDetail(dayKey: dayKey) else {
        return .notFound(.init(body: .json(Self.errorBody("No journal entry for \(dayKey)."))))
      }
      let response = Components.Schemas.JournalEntryDetailResponse(
        date: detail.dateKey,
        journal_relative_path: detail.journalRelativePath,
        content: detail.content,
        word_count: detail.wordCount,
        line_count: detail.lineCount)
      return .ok(.init(body: .json(response)))
    } catch JournalQueryError.invalidJournalDayKey {
      return .badRequest(
        .init(
          body: .json(
            Self.errorBody("journal_day must be formatted yy-MM-dd."))))
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(
              event: "journal.detail.failure",
              error,
              public: "Failed to read journal entry."))))
    }
  }

  // MARK: POST /journal/entries

  func appendJournalEntry(
    _ input: Operations.appendJournalEntry.Input
  ) async throws -> Operations.appendJournalEntry.Output {
    guard case .json(let body) = input.body else {
      return .badRequest(.init(body: .json(Self.errorBody("Request body must be JSON."))))
    }
    guard !body.subject_ids.isEmpty else {
      return .badRequest(.init(body: .json(Self.errorBody("subject_ids must not be empty."))))
    }

    do {
      let path = try await journalStore.appendEntry(
        subjectIds: body.subject_ids,
        body: body.body,
        createdAt: body.created_at,
        journalDayKey: body.journal_day)
      return .created(.init(body: .json(.init(journal_relative_path: path))))
    } catch let error as JournalServiceError {
      return .badRequest(.init(body: .json(Self.errorBody(error.description))))
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(
              event: "journal.append.failure",
              error,
              public: "Failed to persist journal entry."))))
    }
  }

  // MARK: POST /sessions

  func createSession(
    _ input: Operations.createSession.Input
  ) async throws -> Operations.createSession.Output {
    guard case .json(let body) = input.body else {
      return .badRequest(.init(body: .json(Self.errorBody("Request body must be JSON."))))
    }

    let prompt = body.systemPrompt ?? systemPrompt
    let tools: [any ScribeTool] = [ShellTool(), ReadFileTool(), WriteFileTool(), EditFileTool()]
    let config = ScribeConfig(
      agentModel: agentModel,
      contextWindow: contextWindow,
      contextWindowThreshold: contextWindowThreshold,
      serverURL: defaultOllamaURL,
      apiKey: bearerToken,
      tools: tools,
      workingDirectory: workingDirectory)

    let agent = try ScribeAgent(configuration: config, systemPrompt: prompt)
    let id = await store.create(agent: agent)

    log.info("event=session.create id=\(id) model=\(agentModel)")

    let session = await store.get(id)
    let response = Components.Schemas.CreateSessionResponse(
      id: id.uuidString,
      createdAt: session?.createdAt ?? Date())
    return .ok(.init(body: .json(response)))
  }

  // MARK: POST /sessions/{id}/completions/stream

  func runCompletionStream(
    _ input: Operations.runCompletionStream.Input
  ) async throws -> Operations.runCompletionStream.Output {

    guard let sessionId = UUID(uuidString: input.path.id) else {
      return .badRequest(.init(body: .json(Self.errorBody("Invalid or missing session id."))))
    }
    guard case .json(let body) = input.body else {
      return .badRequest(.init(body: .json(Self.errorBody("Request body must be JSON."))))
    }
    guard let session = await store.get(sessionId) else {
      return .notFound(.init(body: .json(Self.errorBody("Session not found."))))
    }

    let turnLog = Logger(label: "scribe.agent.turn.stream.\(sessionId)")
    let turnStream = await session.agent.prompt(body.message, log: turnLog)

    let lineStream = AsyncStream<Components.Schemas.CompletionStreamEvent> { continuation in
      Task { [sessionId, log] in
        do {
          for await event in turnStream.events {
            continuation.yield(CompletionStreamTranscriptMapping.line(for: event))
          }

          let result = try await turnStream.result.value
          let assistantText =
            result.messages.last(where: { $0.role == .assistant })?.content ?? ""

          if assistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            continuation.yield(.init(kind: .harness_error, harness_error_message: "No assistant response."))
            continuation.finish()
            return
          }

          log.info(
            "event=completion.stream.end session=\(sessionId) assistant_chars=\(assistantText.count)")

          continuation.yield(
            .init(
              kind: .done,
              outcome: CompletionStreamTranscriptMapping.outcome(result.outcome),
              tool_round_limit_rounds: CompletionStreamTranscriptMapping.toolRoundLimitRounds(result.outcome),
              assistant_full_text: assistantText))
          continuation.finish()
        } catch {
          continuation.yield(.init(kind: .harness_error, harness_error_message: error.localizedDescription))
          continuation.finish()
        }
      }
    }

    let httpBody = HTTPBody(
      lineStream.asEncodedJSONLines(),
      length: .unknown,
      iterationBehavior: .single)
    return .ok(.init(body: .application_jsonl(httpBody)))
  }

  // MARK: - Internals

  private static func schemaSubjects(_ file: JournalSubjectsFile) -> [Components.Schemas.JournalSubject] {
    file.subjects.map { .init(id: $0.id, label: $0.label) }
  }
}
