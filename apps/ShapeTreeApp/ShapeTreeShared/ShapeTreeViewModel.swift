import Foundation
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import ShapeTreeClient
import SwiftUI

@Observable
@MainActor
public final class ShapeTreeViewModel {

  fileprivate static let unauthorizedMessage =
    "Unauthorized (401). This device's public key isn't enrolled on the server. Tap the network icon to copy the public JWK, then drop it into the server's authorized_keys/<kid>.jwk."

  /// The single mapping for HTTP statuses without a typed `case`. 401 always means
  /// "device not enrolled" because this API requires bearer auth on every route.
  private static func messageForStatus(_ code: Int, fallback: String) -> String {
    code == 401 ? unauthorizedMessage : fallback
  }

  /// Pulls the operator-facing message off an `HTTPErrorResponse` body decoder.
  private static func httpErrorLine(
    _ decode: () throws -> Components.Schemas.HTTPErrorResponse
  ) rethrows -> String {
    try decode().error.message
  }

  public static let serverURL = "http://localhost:42069"

  public var messages: [ChatMessage] = []
  public var inputText: String = ""
  public var isLoading: Bool = false
  public var errorMessage: String? = nil

  public struct JournalSubjectRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
      self.id = id
      self.label = label
    }
  }

  public var journalSubjects: [JournalSubjectRow] = []
  public var journalSelectedSubjectIDs: Set<String> = Set(["general"])
  public var journalDraft: String = ""
  public var journalStatus: String? = nil
  public var journalError: String? = nil
  public var journalCalendarError: String? = nil
  public var isJournalWorking: Bool = false

  public var serverURL: String {
    didSet {
      invalidateOpenAPIClientAndAgentSession()
      journalSubjects.removeAll()
      journalStatus = nil
      journalError = nil
      journalCalendarError = nil
      journalSelectedSubjectIDs = []
    }
  }

  public let keyStore: ShapeTreeKeyStore

  /// Shared generated client — same bearer middleware stack for journal and chat paths.
  private var sharedOpenAPIClient: Client?
  private var sessionId: String?
  private let transport: AsyncHTTPClientTransport

  public init(
    serverURL: String,
    keyStore: ShapeTreeKeyStore = ShapeTreeKeyStore()
  ) {
    self.transport = AsyncHTTPClientTransport()
    self.keyStore = keyStore
    self.serverURL = serverURL

    _ = try? keyStore.loadOrGenerate()
  }

  private func makeClient() throws -> Client {
    guard let endpoint = URL(string: serverURL) else {
      throw AppError.invalidURL(serverURL)
    }
    let store = keyStore
    let middlewares: [any ClientMiddleware] = [
      BearerAuthClientMiddleware(tokenProvider: { @Sendable in
        try await MainActor.run { try store.mintES256JWT(ttl: 900) }
      })
    ]
    return Client(serverURL: endpoint, transport: transport, middlewares: middlewares)
  }

  public func currentPublicJWKJSON() -> String? {
    try? keyStore.publicJWKJSON()
  }

  public func currentKid() -> String? {
    try? keyStore.kid()
  }

  public func regenerateDeviceKey() throws {
    try keyStore.regenerate()
    invalidateOpenAPIClientAndAgentSession()
  }

  public func sendMessage() {
    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isLoading else { return }

    messages.append(ChatMessage(content: trimmed, isUser: true))
    inputText = ""
    isLoading = true
    errorMessage = nil

    let placeholderID = UUID()
    messages.append(ChatMessage(id: placeholderID, assistantBlocks: []))

    Task { @MainActor in
      do {
        try await consumeStreamingCompletion(placeholderID: placeholderID, userMessage: trimmed)
      } catch {
        removePlaceholder(id: placeholderID, isLoading: false)
        errorMessage = error.localizedDescription
      }
    }
  }

  private func replaceAssistantPlaceholder(
    id: UUID, blocks: [AssistantTimelineBlock], isLoading: Bool
  ) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[index] = ChatMessage(id: id, assistantBlocks: blocks)
    self.isLoading = isLoading
  }

  private func updateAssistantPlaceholder(id: UUID, blocks: [AssistantTimelineBlock]) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[index] = ChatMessage(id: id, assistantBlocks: blocks)
  }

  private func removePlaceholder(id: UUID, isLoading: Bool) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    if messages[index].isAssistantPlaceholderVisuallyEmpty {
      messages.remove(at: index)
    }
    self.isLoading = isLoading
  }

  public func reset() {
    messages.removeAll()
    inputText = ""
    isLoading = false
    errorMessage = nil
    invalidateOpenAPIClientAndAgentSession()

    journalDraft = ""
    journalStatus = nil
    journalError = nil
    journalSelectedSubjectIDs = Set(["general"])
    journalSubjects.removeAll()
  }

  private func openAPIClient() throws -> Client {
    if let client = sharedOpenAPIClient {
      return client
    }
    let built = try makeClient()
    sharedOpenAPIClient = built
    return built
  }

  private func invalidateOpenAPIClientAndAgentSession() {
    sharedOpenAPIClient = nil
    sessionId = nil
  }

  private func invalidateAgentSessionOnly() {
    sessionId = nil
  }

  private func ensureSession() async throws -> Client {
    let api = try openAPIClient()
    if sessionId != nil { return api }

    let response = try await api.createSession(
      Operations.createSession.Input(body: .json(.init(systemPrompt: nil)))
    )

    switch response {
    case .ok(let ok):
      sessionId = try ok.body.json.id
      return api
    case .badRequest(let err):
      throw AppError.server(try Self.httpErrorLine { try err.body.json })
    case .undocumented(let statusCode, _):
      throw AppError.server(Self.messageForStatus(statusCode, fallback: "Server returned status \(statusCode)"))
    }
  }

  private func consumeStreamingCompletion(placeholderID: UUID, userMessage: String) async throws {
    let workingClient = try await ensureSession()
    guard let sid = sessionId else {
      throw AppError.server("No active session.")
    }

    let response = try await workingClient.runCompletionStream(
      path: .init(id: sid),
      body: .json(.init(message: userMessage))
    )

    switch response {
    case .ok(let ok):
      let stream = try ok.decodedCompletionEvents()
      var blocks: [AssistantTimelineBlock] = []

      /// Merge `fragment` into the last block when it matches `kind`; otherwise append a new block
      /// of the same shape. Replaces the previous duplicate appendReasoning/appendAnswer closures.
      func appendStreamFragment(_ fragment: String, section: Components.Schemas.CompletionStreamSection) {
        guard !fragment.isEmpty else { return }
        if let last = blocks.last {
          switch (last.kind, section) {
          case (.reasoning(let prior), .reasoning):
            blocks.removeLast()
            blocks.append(.init(id: last.id, kind: .reasoning(prior + fragment)))
            return
          case (.answer(let prior), .answer):
            blocks.removeLast()
            blocks.append(.init(id: last.id, kind: .answer(prior + fragment)))
            return
          default:
            break
          }
        }
        blocks.append(
          .init(kind: section == .reasoning ? .reasoning(fragment) : .answer(fragment)))
      }

      func hasNonemptyAnswerBlock() -> Bool {
        blocks.contains {
          guard case .answer(let s) = $0.kind else { return false }
          return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
      }

      for try await event in stream {
        switch event.kind {
        case .assistant_delta:
          guard let fragment = event.text, !fragment.isEmpty else { continue }
          appendStreamFragment(fragment, section: event.stream_section ?? .answer)
          updateAssistantPlaceholder(id: placeholderID, blocks: blocks)

        case .tool_round:
          let round = event.round ?? 0
          blocks.append(
            .init(kind: .toolRound(round: round, toolNames: event.tool_names ?? [])))
          updateAssistantPlaceholder(id: placeholderID, blocks: blocks)

        case .tool_invocation:
          blocks.append(
            .init(kind: .toolCall(
              toolName: event.tool_name ?? "",
              arguments: event.tool_arguments ?? "",
              output: event.tool_output ?? "")))
          updateAssistantPlaceholder(id: placeholderID, blocks: blocks)

        case .done:
          if let full = event.assistant_full_text,
            !hasNonemptyAnswerBlock(),
            !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          {
            appendStreamFragment(full, section: .answer)
          }
          replaceAssistantPlaceholder(id: placeholderID, blocks: blocks, isLoading: false)
          return

        case .harness_error:
          throw AppError.server(event.harness_error_message ?? "Agent error.")

        default:
          continue
        }
      }
      throw AppError.server("Stream ended unexpectedly.")

    case .badRequest(let err):
      throw AppError.server(try Self.httpErrorLine { try err.body.json })
    case .notFound:
      invalidateAgentSessionOnly()
      throw AppError.server("Session expired. Please try again.")
    case .internalServerError(let err):
      throw AppError.server(try Self.httpErrorLine { try err.body.json })
    case .undocumented(let statusCode, _):
      throw AppError.server(Self.messageForStatus(statusCode, fallback: "Server returned status \(statusCode)"))
    }
  }

  public func reportJournalCalendarLoadFailure(_ error: Error) {
    journalCalendarError = error.localizedDescription
  }

  public func clearJournalCalendarError() {
    journalCalendarError = nil
  }

  public func refreshJournalSubjects() async {
    journalError = nil
    journalStatus = nil
    guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      journalError = "Enter a ShapeTree server URL first."
      return
    }

    // Subject list refresh runs on tab load and from the composer; do not use the global
    // `isJournalWorking` overlay here — a slow or hung server would block the whole journal UI.
    do {
      let remote = try openAPIClient()
      let response = try await remote.listJournalSubjects(.init(headers: .init()))

      switch response {
      case .ok(let packet):
        let payload = try packet.body.json
        journalSubjects = payload.subjects.map { JournalSubjectRow(id: $0.id, label: $0.label) }

        let validIds = Set(journalSubjects.map(\.id))
        journalSelectedSubjectIDs.formIntersection(validIds)

        if journalSelectedSubjectIDs.isEmpty {
          if validIds.contains("general") {
            journalSelectedSubjectIDs = Set(["general"])
          } else if let firstSubject = journalSubjects.first {
            journalSelectedSubjectIDs = Set([firstSubject.id])
          }
        }

        journalStatus =
          journalSubjects.isEmpty ? "Server returned zero subjects." : "\(journalSubjects.count) subjects loaded."

      case .internalServerError(let err):
        journalError = try Self.httpErrorLine { try err.body.json }

      case .undocumented(let statusCode, _):
        journalError = Self.messageForStatus(
          statusCode, fallback: "Unexpected status \(statusCode) while fetching subjects.")
      }
    } catch {
      journalError = error.localizedDescription
    }
  }

  public func toggleJournalSubjectSelection(_ subjectId: String) {
    if journalSelectedSubjectIDs.contains(subjectId) {
      journalSelectedSubjectIDs.remove(subjectId)
    } else {
      journalSelectedSubjectIDs.insert(subjectId)
    }
  }

  @discardableResult
  public func appendJournalSubjectAndRefresh(_ rawName: String) async -> Bool {
    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      journalError = "Enter a subject name before adding."
      return false
    }
    guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      journalError = "Enter a ShapeTree server URL first."
      return false
    }

    journalError = nil
    journalStatus = nil
    isJournalWorking = true
    defer { isJournalWorking = false }

    do {
      let remote = try openAPIClient()
      let response = try await remote.appendJournalSubject(
        Operations.appendJournalSubject.Input(body: .json(.init(subject: name)))
      )

      switch response {
      case .ok(let packet):
        let payload = try packet.body.json
        journalSubjects = payload.subjects.map { JournalSubjectRow(id: $0.id, label: $0.label) }
        if let row = payload.subjects.first(where: { $0.label.caseInsensitiveCompare(name) == .orderedSame }) {
          journalSelectedSubjectIDs.insert(row.id)
        }
        journalStatus = "Subject \"\(name)\" is available."
        return true

      case .badRequest(let err):
        journalError = try Self.httpErrorLine { try err.body.json }

      case .internalServerError(let err):
        journalError = try Self.httpErrorLine { try err.body.json }

      case .unauthorized:
        journalError = Self.unauthorizedMessage

      case .undocumented(let code, _):
        journalError = Self.messageForStatus(code, fallback: "Unexpected status \(code) while adding subject.")
      }
    } catch {
      journalError = error.localizedDescription
    }
    return false
  }

  public func appendJournalEntryUsingServer(filingDate: Date = Date()) async {
    let bodyText = journalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !bodyText.isEmpty else {
      journalError = "Write something before appending."
      return
    }
    guard !journalSelectedSubjectIDs.isEmpty else {
      journalError = "Select at least one subject (tap + to create one if the list is empty)."
      return
    }

    journalError = nil
    journalStatus = nil
    isJournalWorking = true
    defer { isJournalWorking = false }

    do {
      let remote = try openAPIClient()
      let payload = Components.Schemas.AppendJournalEntryRequest(
        subject_ids: Array(journalSelectedSubjectIDs).sorted(),
        body: bodyText,
        journal_day: JournalPathCodec.journalDayKey(for: filingDate, calendar: .autoupdatingCurrent),
        created_at: nil)

      let response = try await remote.appendJournalEntry(
        Operations.appendJournalEntry.Input(body: .json(payload))
      )

      switch response {
      case .created(let packet):
        let summary = try packet.body.json
        journalDraft = ""
        journalStatus = "Saved Markdown at repo path \(summary.journal_relative_path)."

      case .badRequest(let err):
        journalError = try Self.httpErrorLine { try err.body.json }

      case .internalServerError(let err):
        journalError = try Self.httpErrorLine { try err.body.json }

      case .undocumented(let code, _):
        journalError = Self.messageForStatus(code, fallback: "Unexpected status \(code) while appending.")
      }
    } catch {
      journalError = error.localizedDescription
    }
  }

  public func fetchJournalEntrySummaries(startDayKey: String, endDayKey: String) async throws
    -> [Components.Schemas.JournalEntrySummary]
  {
    let remote = try openAPIClient()
    let response = try await remote.listJournalEntrySummaries(
      Operations.listJournalEntrySummaries.Input(
        query: .init(start_date: startDayKey, end_date: endDayKey)))

    switch response {
    case .ok(let packet):
      return try packet.body.json.entries
    case .badRequest(let err):
      throw AppError.server(try Self.httpErrorLine { try err.body.json })
    case .internalServerError(let err):
      throw AppError.server(try Self.httpErrorLine { try err.body.json })
    case .undocumented(let code, _):
      throw AppError.server(
        Self.messageForStatus(code, fallback: "Unexpected status \(code) while listing journal entries."))
    }
  }

  public func fetchJournalEntryDetailIfPresent(dayKey: String) async throws -> Components.Schemas
    .JournalEntryDetailResponse?
  {
    let remote = try openAPIClient()
    let response = try await remote.getJournalEntryDetail(
      Operations.getJournalEntryDetail.Input(path: .init(journal_day: dayKey)))

    switch response {
    case .ok(let packet):
      return try packet.body.json
    case .notFound:
      return nil
    case .badRequest(let err):
      throw AppError.server(try Self.httpErrorLine { try err.body.json })
    case .internalServerError(let err):
      throw AppError.server(try Self.httpErrorLine { try err.body.json })
    case .undocumented(let code, _):
      throw AppError.server(
        Self.messageForStatus(code, fallback: "Unexpected status \(code) while loading journal entry."))
    }
  }
}
