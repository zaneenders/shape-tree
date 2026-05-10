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
  let journalService: JournalService
  let journalQuery: JournalQueryService
  let log: Logger
  let defaultOllamaURL: String
  let agentModel: String
  let systemPrompt: String
  let bearerToken: String?
  let contextWindow: Int
  let contextWindowThreshold: Double
  let workingDirectory: String

  // MARK: GET /journal/subjects

  func listJournalSubjects(
    _ input: Operations.listJournalSubjects.Input
  ) async throws -> Operations.listJournalSubjects.Output {
    do {
      let file = try await journalService.loadSubjects()
      let subjects = file.subjects.map {
        Components.Schemas.JournalSubject(id: $0.id, label: $0.label)
      }
      let response = Components.Schemas.JournalSubjectsResponse(subjects: subjects)
      return .ok(.init(body: .json(response)))
    } catch {
      log.error("event=journal.subjects.failure error=\(error.localizedDescription)")
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Could not load journal subjects.")
      )
      return .internalServerError(.init(body: .json(payload)))
    }
  }

  // MARK: POST /journal/subjects

  func appendJournalSubject(
    _ input: Operations.appendJournalSubject.Input
  ) async throws -> Operations.appendJournalSubject.Output {
    guard case .json(let body) = input.body else {
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Request body must be JSON.")
      )
      return .badRequest(.init(body: .json(payload)))
    }

    do {
      let file = try await journalService.appendSubject(rawLabel: body.subject)
      let subjects = file.subjects.map {
        Components.Schemas.JournalSubject(id: $0.id, label: $0.label)
      }
      let response = Components.Schemas.JournalSubjectsResponse(subjects: subjects)
      return .ok(.init(body: .json(response)))
    } catch let error as JournalServiceError {
      switch error {
      case .emptySubjectLabel:
        let payload = Components.Schemas.HTTPErrorResponse(
          error: .init(message: error.description)
        )
        return .badRequest(.init(body: .json(payload)))
      case .emptySubjects, .utf8EncodingFailed, .invalidJournalDayKey:
        log.error("event=journal.subjects.append.unexpected_journal_error error=\(error.description)")
        let payload = Components.Schemas.HTTPErrorResponse(
          error: .init(message: "Failed to append journal subject.")
        )
        return .internalServerError(.init(body: .json(payload)))
      }
    } catch {
      log.error("event=journal.subjects.append.failure error=\(error.localizedDescription)")
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Failed to append journal subject.")
      )
      return .internalServerError(.init(body: .json(payload)))
    }
  }

  // MARK: GET /journal/entries

  func listJournalEntrySummaries(
    _ input: Operations.listJournalEntrySummaries.Input
  ) async throws -> Operations.listJournalEntrySummaries.Output {
    let start = input.query.start_date
    let end = input.query.end_date

    do {
      let rows = try journalQuery.listSummaries(startDayKey: start, endDayKey: end)
      let entries = rows.map {
        Components.Schemas.JournalEntrySummary(
          date: $0.dateKey,
          journal_relative_path: $0.journalRelativePath,
          word_count: $0.wordCount,
          line_count: $0.lineCount
        )
      }
      let response = Components.Schemas.JournalEntriesSummariesResponse(entries: entries)
      return .ok(.init(body: .json(response)))
    } catch JournalQueryError.invalidJournalDayKey {
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "start_date and end_date must be formatted yy-MM-dd.")
      )
      return .badRequest(.init(body: .json(payload)))
    } catch JournalQueryError.invalidRange {
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "start_date must be on or before end_date.")
      )
      return .badRequest(.init(body: .json(payload)))
    } catch {
      log.error("event=journal.summaries.failure error=\(error.localizedDescription)")
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Failed to list journal entries.")
      )
      return .internalServerError(.init(body: .json(payload)))
    }
  }

  // MARK: GET /journal/entries/{journal_day}

  func getJournalEntryDetail(
    _ input: Operations.getJournalEntryDetail.Input
  ) async throws -> Operations.getJournalEntryDetail.Output {
    let dayKey = input.path.journal_day

    do {
      guard let detail = try journalQuery.entryDetail(dayKey: dayKey) else {
        let payload = Components.Schemas.HTTPErrorResponse(
          error: .init(message: "No journal entry for \(dayKey).")
        )
        return .notFound(.init(body: .json(payload)))
      }

      let response = Components.Schemas.JournalEntryDetailResponse(
        date: detail.dateKey,
        journal_relative_path: detail.journalRelativePath,
        content: detail.content,
        word_count: detail.wordCount,
        line_count: detail.lineCount
      )
      return .ok(.init(body: .json(response)))
    } catch JournalQueryError.invalidJournalDayKey {
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "journal_day must be formatted yy-MM-dd.")
      )
      return .badRequest(.init(body: .json(payload)))
    } catch {
      log.error("event=journal.detail.failure error=\(error.localizedDescription)")
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Failed to read journal entry.")
      )
      return .internalServerError(.init(body: .json(payload)))
    }
  }

  // MARK: POST /journal/entries

  func appendJournalEntry(
    _ input: Operations.appendJournalEntry.Input
  ) async throws -> Operations.appendJournalEntry.Output {
    guard case .json(let body) = input.body else {
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Request body must be JSON.")
      )
      return .badRequest(.init(body: .json(payload)))
    }

    guard !body.subject_ids.isEmpty else {
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "subject_ids must not be empty.")
      )
      return .badRequest(.init(body: .json(payload)))
    }

    do {
      let path = try await journalService.appendEntry(
        subjectIds: body.subject_ids,
        body: body.body,
        createdAt: body.created_at,
        journalDayKey: body.journal_day)

      let response = Components.Schemas.AppendJournalEntryResponse(
        journal_relative_path: path)
      return .created(.init(body: .json(response)))
    } catch let error as JournalServiceError {
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: error.description))
      return .badRequest(.init(body: .json(payload)))
    } catch {
      log.error("event=journal.append.failure error=\(error.localizedDescription)")
      let payload = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Failed to persist journal entry.")
      )
      return .internalServerError(.init(body: .json(payload)))
    }
  }

  // MARK: POST /sessions

  func createSession(
    _ input: Operations.createSession.Input
  ) async throws -> Operations.createSession.Output {
    guard case .json(let body) = input.body else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Request body must be JSON.")
      )
      return .badRequest(.init(body: .json(error)))
    }

    let prompt = body.systemPrompt ?? systemPrompt

    let tools: [any ScribeTool] = [
      ShellTool(),
      ReadFileTool(),
      WriteFileTool(),
      EditFileTool(),
    ]

    let config = ScribeConfig(
      agentModel: agentModel,
      contextWindow: contextWindow,
      contextWindowThreshold: contextWindowThreshold,
      serverURL: defaultOllamaURL,
      apiKey: bearerToken,
      tools: tools,
      workingDirectory: workingDirectory
    )

    let agent = try ScribeAgent(
      configuration: config,
      systemPrompt: prompt
    )

    let id = await store.create(agent: agent, systemPrompt: prompt)

    log.info(
      """
      event=session.create \
      id=\(id) \
      model=\(agentModel)
      """)

    let session = await store.get(id)
    let response = Components.Schemas.CreateSessionResponse(
      id: id.uuidString,
      createdAt: session?.createdAt ?? Date()
    )
    return .ok(.init(body: .json(response)))
  }

  // MARK: POST /sessions/{id}/completions/stream

  func runCompletionStream(
    _ input: Operations.runCompletionStream.Input
  ) async throws -> Operations.runCompletionStream.Output {

    guard let sessionId = UUID(uuidString: input.path.id) else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Invalid or missing session id.")
      )
      return .badRequest(.init(body: .json(error)))
    }

    guard case .json(let body) = input.body else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Request body must be JSON.")
      )
      return .badRequest(.init(body: .json(error)))
    }

    guard let session = await store.get(sessionId) else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Session not found.")
      )
      return .notFound(.init(body: .json(error)))
    }

    let turnLog = Logger(label: "scribe.agent.turn.stream.\(sessionId)")
    let turnStream = await session.agent.prompt(body.message, log: turnLog)

    let lineStream = AsyncStream<Components.Schemas.CompletionStreamEvent> { continuation in
      Task { [sessionId, store, log] in
        do {
          for await event in turnStream.events {
            let schemaLine = CompletionStreamTranscriptMapping.line(for: event)
            continuation.yield(schemaLine)
          }

          let result = try await turnStream.result.value
          await store.setMessages(sessionId, messages: result.messages)

          let assistantText =
            result.messages.last(where: { $0.role == .assistant })?.content ?? ""

          if assistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            continuation.yield(
              Components.Schemas.CompletionStreamEvent(
                kind: .harness_error,
                harness_error_message: "No assistant response."
              ))
            continuation.finish()
            return
          }

          log.info(
            """
            event=completion.stream.end \
            session=\(sessionId) \
            assistant_chars=\(assistantText.count)
            """)

          continuation.yield(
            Components.Schemas.CompletionStreamEvent(
              kind: .done,
              outcome: CompletionStreamTranscriptMapping.outcome(result.outcome),
              tool_round_limit_rounds: CompletionStreamTranscriptMapping.toolRoundLimitRounds(
                result.outcome),
              assistant_full_text: assistantText
            ))
          continuation.finish()
        } catch {
          continuation.yield(
            Components.Schemas.CompletionStreamEvent(
              kind: .harness_error,
              harness_error_message: error.localizedDescription
            ))
          continuation.finish()
        }
      }
    }

    let httpBody = HTTPBody(
      lineStream.asEncodedJSONLines(),
      length: .unknown,
      iterationBehavior: .single
    )
    return .ok(.init(body: .application_jsonl(httpBody)))
  }
}
