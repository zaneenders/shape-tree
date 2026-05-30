import Foundation
import OpenAPIRuntime
import ShapeTreeClient
import Workflow

extension ShapeTreeHandler {

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
      let rows = try await journalStore.listMetrics(
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

      let dayKey = body.journal_day ?? JournalPathCodec.journalDayKey(for: Date())
      await worker?.enqueue(key: dayKey)

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

  private static func schemaSubjects(_ file: JournalSubjectsFile) -> [Components.Schemas.JournalSubject] {
    file.subjects.map { .init(id: $0.id, label: $0.label) }
  }
}
