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

  private static let serverURLDefaultsKey = "shape_tree_server_url"

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
  /// Load failures for the journal calendar grid (separate from composer / subject `journalError`).
  public var journalCalendarError: String? = nil
  public var isJournalWorking: Bool = false

  public var serverURL: String {
    didSet {
      UserDefaults.standard.set(serverURL, forKey: Self.serverURLDefaultsKey)
      resetSession()
      journalSubjects.removeAll()
      journalStatus = nil
      journalError = nil
      journalCalendarError = nil
      journalSelectedSubjectIDs = []
    }
  }

  public let keyStore: ShapeTreeKeyStore

  private var client: Client?
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
    let middlewares: [any ClientMiddleware] = [
      ShapeTreeAutoMintBearer(keyStore: keyStore)
    ]
    return Client(serverURL: endpoint, transport: transport, middlewares: middlewares)
  }

  public func currentPublicJWKJSON() -> String? {
    try? keyStore.publicJWKJSON()
  }

  public func currentKid() -> String? {
    try? keyStore.kid()
  }

  /// Forces a key rotation. Existing sessions are invalidated; the operator
  /// must drop the new public JWK into the server's `authorized_keys/`.
  public func regenerateDeviceKey() throws {
    try keyStore.regenerate()
    resetSession()
  }

  public func sendMessage() {
    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isLoading else { return }

    messages.append(ChatMessage(content: trimmed, isUser: true))
    inputText = ""
    isLoading = true
    errorMessage = nil

    let placeholderID = UUID()
    messages.append(
      ChatMessage(id: placeholderID, assistantBlocks: [])
    )

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
    resetSession()

    journalDraft = ""
    journalStatus = nil
    journalError = nil
    journalSelectedSubjectIDs = Set(["general"])
    journalSubjects.removeAll()
  }

  private func resetSession() {
    sessionId = nil
    client = nil
  }

  private func ensureSession() async throws -> Client {
    if let client, sessionId != nil {
      return client
    }

    let freshClient = try makeClient()

    let response = try await freshClient.createSession(
      Operations.createSession.Input(body: .json(.init(systemPrompt: nil)))
    )

    switch response {
    case .ok(let ok):
      let payload = try ok.body.json
      sessionId = payload.id
      client = freshClient
      return freshClient

    case .badRequest(let err):
      let body = try err.body.json
      throw AppError.server(body.error.message)

    case .undocumented(let statusCode, _):
      if statusCode == 401 {
        throw AppError.server(Self.unauthorizedMessage)
      }
      throw AppError.server("Server returned status \(statusCode)")
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

      func appendReasoning(_ fragment: String) {
        guard !fragment.isEmpty else { return }
        if let last = blocks.last, case .reasoning(let prior) = last.kind {
          blocks.removeLast()
          blocks.append(
            AssistantTimelineBlock(id: last.id, kind: .reasoning(prior + fragment)))
        } else {
          blocks.append(AssistantTimelineBlock(kind: .reasoning(fragment)))
        }
      }

      func appendAnswer(_ fragment: String) {
        guard !fragment.isEmpty else { return }
        if let last = blocks.last, case .answer(let prior) = last.kind {
          blocks.removeLast()
          blocks.append(AssistantTimelineBlock(id: last.id, kind: .answer(prior + fragment)))
        } else {
          blocks.append(AssistantTimelineBlock(kind: .answer(fragment)))
        }
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
          switch event.stream_section {
          case .some(.reasoning):
            appendReasoning(fragment)
          case .some(.answer), .none:
            appendAnswer(fragment)
          }
          updateAssistantPlaceholder(id: placeholderID, blocks: blocks)

        case .tool_round:
          let round = event.round ?? 0
          blocks.append(
            AssistantTimelineBlock(kind: .toolRound(round: round, toolNames: event.tool_names ?? []))
          )
          updateAssistantPlaceholder(id: placeholderID, blocks: blocks)

        case .tool_invocation:
          blocks.append(
            AssistantTimelineBlock(
              kind: .toolCall(
                toolName: event.tool_name ?? "",
                arguments: event.tool_arguments ?? "",
                output: event.tool_output ?? ""
              ))
          )
          updateAssistantPlaceholder(id: placeholderID, blocks: blocks)

        case .done:
          if let full = event.assistant_full_text,
            !hasNonemptyAnswerBlock(),
            !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          {
            appendAnswer(full)
          }
          replaceAssistantPlaceholder(id: placeholderID, blocks: blocks, isLoading: false)
          return

        case .harness_error:
          let msg = event.harness_error_message ?? "Agent error."
          throw AppError.server(msg)

        default:
          continue
        }
      }
      throw AppError.server("Stream ended unexpectedly.")

    case .badRequest(let err):
      let body = try err.body.json
      throw AppError.server(body.error.message)
    case .notFound:
      resetSession()
      throw AppError.server("Session expired. Please try again.")
    case .internalServerError(let err):
      let body = try err.body.json
      throw AppError.server(body.error.message)
    case .undocumented(let statusCode, _):
      if statusCode == 401 {
        throw AppError.server(Self.unauthorizedMessage)
      }
      throw AppError.server("Server returned status \(statusCode)")
    }
  }

  /// Two-digit journal day key `yy-MM-dd` for the device's local civil day (sent as `journal_day` on append).
  private static func localJournalDayKey(for date: Date) -> String {
    let calendar = Calendar.autoupdatingCurrent
    let yy = calendar.component(.year, from: date) % 100
    let mm = calendar.component(.month, from: date)
    let dd = calendar.component(.day, from: date)
    return String(format: "%02d-%02d-%02d", yy, mm, dd)
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
      let remote = try makeClient()
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
        let body = try err.body.json
        journalError = body.error.message

      case .undocumented(let statusCode, _):
        if statusCode == 401 {
          journalError = Self.unauthorizedMessage
        } else {
          journalError = "Unexpected status \(statusCode) while fetching subjects."
        }
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
      journalError =
        "Enter a subject name before adding."
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
      let remote = try makeClient()
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
        let body = try err.body.json
        journalError = body.error.message

      case .internalServerError(let err):
        let body = try err.body.json
        journalError = body.error.message

      case .unauthorized:
        journalError = Self.unauthorizedMessage

      case .undocumented(let code, _):
        if code == 401 {
          journalError = Self.unauthorizedMessage
        } else {
          journalError = "Unexpected status \(code) while adding subject."
        }
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
      journalError =
        "Select at least one subject (tap + to create one if the list is empty)."
      return
    }

    journalError = nil
    journalStatus = nil
    isJournalWorking = true
    defer { isJournalWorking = false }

    do {
      let remote = try makeClient()
      let payload = Components.Schemas.AppendJournalEntryRequest(
        subject_ids: Array(journalSelectedSubjectIDs).sorted(),
        body: bodyText,
        journal_day: Self.localJournalDayKey(for: filingDate),
        created_at: nil
      )

      let response = try await remote.appendJournalEntry(
        Operations.appendJournalEntry.Input(body: .json(payload))
      )

      switch response {
      case .created(let packet):
        let summary = try packet.body.json
        journalDraft = ""
        journalStatus =
          "Saved Markdown at repo path \(summary.journal_relative_path)."

      case .badRequest(let err):
        let body = try err.body.json
        journalError = body.error.message

      case .internalServerError(let err):
        let body = try err.body.json
        journalError = body.error.message

      case .undocumented(let code, _):
        if code == 401 {
          journalError = Self.unauthorizedMessage
        } else {
          journalError = "Unexpected status \(code) while appending."
        }
      }
    } catch {
      journalError = error.localizedDescription
    }
  }

  /// Lists journal entry metadata for each day in the span `[startDayKey, endDayKey]` (`yy-MM-dd`, device-local calendar).
  public func fetchJournalEntrySummaries(startDayKey: String, endDayKey: String) async throws
    -> [Components.Schemas.JournalEntrySummary]
  {
    let remote = try makeClient()
    let response = try await remote.listJournalEntrySummaries(
      Operations.listJournalEntrySummaries.Input(
        query: .init(start_date: startDayKey, end_date: endDayKey)
      ))

    switch response {
    case .ok(let packet):
      let payload = try packet.body.json
      return payload.entries
    case .badRequest(let err):
      let body = try err.body.json
      throw AppError.server(body.error.message)
    case .internalServerError(let err):
      let body = try err.body.json
      throw AppError.server(body.error.message)
    case .undocumented(let code, _):
      if code == 401 {
        throw AppError.server(Self.unauthorizedMessage)
      }
      throw AppError.server("Unexpected status \(code) while listing journal entries.")
    }
  }

  /// Loads Markdown for `journal_day` (`yy-MM-dd`), or nil when the server reports no file.
  public func fetchJournalEntryDetailIfPresent(dayKey: String) async throws -> Components.Schemas
    .JournalEntryDetailResponse?
  {
    let remote = try makeClient()
    let response = try await remote.getJournalEntryDetail(
      Operations.getJournalEntryDetail.Input(path: .init(journal_day: dayKey)))

    switch response {
    case .ok(let packet):
      return try packet.body.json
    case .notFound:
      return nil
    case .badRequest(let err):
      let body = try err.body.json
      throw AppError.server(body.error.message)
    case .internalServerError(let err):
      let body = try err.body.json
      throw AppError.server(body.error.message)
    case .undocumented(let code, _):
      if code == 401 {
        throw AppError.server(Self.unauthorizedMessage)
      }
      throw AppError.server("Unexpected status \(code) while loading journal entry.")
    }
  }
}

// MARK: - Chat models

/// One segment of an assistant turn in stream order (thinking, tools, final reply).
public struct AssistantTimelineBlock: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let kind: Kind

  public enum Kind: Equatable, Sendable {
    case reasoning(String)
    case toolRound(round: Int, toolNames: [String])
    case toolCall(toolName: String, arguments: String, output: String)
    case answer(String)
  }

  public init(id: UUID = UUID(), kind: Kind) {
    self.id = id
    self.kind = kind
  }

  /// Stable scroll / diff signal for streaming updates.
  fileprivate var scrollFingerprintPiece: String {
    switch kind {
    case .reasoning(let s): return "r:\(s)"
    case .answer(let s): return "a:\(s)"
    case .toolRound(let r, let names): return "tr:\(r):\(names.joined(separator: "|"))"
    case .toolCall(let name, let args, let output):
      return "tc:\(name)|\(args)|\(output)"
    }
  }

  fileprivate var isVisuallyEmpty: Bool {
    switch kind {
    case .reasoning(let s), .answer(let s):
      return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .toolRound(_, let names):
      return names.isEmpty
    case .toolCall(let name, let args, let output):
      return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && args.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
}

/// A lightweight chat transcript row used by SwiftUI previews.
public struct ChatMessage: Identifiable, Equatable {
  public let id: UUID
  public let isUser: Bool
  /// User message text; empty for assistant rows.
  public let content: String
  /// Ordered timeline for a single assistant reply (reasoning, tools, answer).
  public let assistantBlocks: [AssistantTimelineBlock]

  /// User message.
  public init(id: UUID = UUID(), content: String, isUser: Bool) {
    self.id = id
    self.isUser = isUser
    self.content = content
    self.assistantBlocks = []
  }

  /// Assistant message built from streamed completion events.
  public init(id: UUID, assistantBlocks: [AssistantTimelineBlock]) {
    self.id = id
    self.isUser = false
    self.content = ""
    self.assistantBlocks = assistantBlocks
  }

  /// Fingerprint so scroll listeners observe streaming placeholder updates for assistant rows.
  public var scrollFingerprint: String {
    if isUser { return content }
    return assistantBlocks.map(\.scrollFingerprintPiece).joined(separator: "\u{1e}")
  }

  fileprivate var isAssistantPlaceholderVisuallyEmpty: Bool {
    assistantBlocks.isEmpty || assistantBlocks.allSatisfy(\.isVisuallyEmpty)
  }
}

// MARK: - Errors

enum AppError: LocalizedError {
  case invalidURL(String)
  case server(String)

  var errorDescription: String? {
    switch self {
    case .invalidURL(let url):
      return "Invalid server URL: \(url)"
    case .server(let message):
      return message
    }
  }
}
