import Foundation
import OpenAPIAsyncHTTPClient
import ShapeTreeClient
import SwiftUI

/// Hosts chat + ShapeTree-specific OpenAPI calls (sessions, completions, journal, push registration).
@Observable
@MainActor
public final class ShapeTreeViewModel {

  // MARK: - Chat UI

  public var messages: [ChatMessage] = []
  public var inputText: String = ""
  public var isLoading: Bool = false
  public var errorMessage: String? = nil

  // MARK: - Journal UI

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
  public var isJournalWorking: Bool = false

  // MARK: - Push notifications

  /// Authorization / registration failures (Scribe-style `AppViewModel.pushNotificationError`).
  public var pushNotificationError: String?

  // MARK: - Runtime configuration

  public var serverURL: String {
    didSet {
      UserDefaults.standard.set(serverURL, forKey: Self.serverURLDefaultsKey)
      resetSession()
      journalSubjects.removeAll()
      journalStatus = nil
      journalError = nil
      journalSelectedSubjectIDs = []
    }
  }

  /// Bearer JWT string (`Authorization: Bearer …`). Mint this elsewhere with the server's **`jwt.secret`**; never embed the secret in the app.
  public var apiBearerToken: String? {
    didSet {
      persistApiBearerToken(apiBearerToken)
      resetSession()
    }
  }

  private var client: Client?
  private var sessionId: String?
  private let transport: AsyncHTTPClientTransport

  private static let serverURLDefaultsKey = "shape_tree_server_url"
  private static let apiBearerTokenDefaultsKey = "shape_tree_api_bearer_token"

  // MARK: - Init

  public init(
    serverURL defaultServerURL: String = "http://127.0.0.1:42069",
    apiBearerToken defaultToken: String? = nil
  ) {
    self.transport = AsyncHTTPClientTransport()

    if let storedURL = UserDefaults.standard.string(forKey: Self.serverURLDefaultsKey)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !storedURL.isEmpty
    {
      self.serverURL = storedURL
    } else {
      self.serverURL = defaultServerURL
    }

    if let storedToken = UserDefaults.standard.string(forKey: Self.apiBearerTokenDefaultsKey)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !storedToken.isEmpty
    {
      self.apiBearerToken = storedToken
    } else {
      self.apiBearerToken = defaultToken
    }
  }

  private func persistApiBearerToken(_ token: String?) {
    let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty {
      UserDefaults.standard.removeObject(forKey: Self.apiBearerTokenDefaultsKey)
    } else {
      UserDefaults.standard.set(trimmed, forKey: Self.apiBearerTokenDefaultsKey)
    }
  }

  private func makeClient() throws -> Client {
    guard let endpoint = URL(string: serverURL) else {
      throw AppError.invalidURL(serverURL)
    }
    let trimmedToken = apiBearerToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let middlewares = ShapeTreeAPIClientMiddleware.bearerJWT(trimmedToken.isEmpty ? nil : trimmedToken)
    return Client(serverURL: endpoint, transport: transport, middlewares: middlewares)
  }

  // MARK: - Chat

  public func sendMessage() {
    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isLoading else { return }

    messages.append(ChatMessage(content: trimmed, isUser: true))
    inputText = ""
    isLoading = true
    errorMessage = nil

    let placeholderID = UUID()
    messages.append(ChatMessage(id: placeholderID, content: "", isUser: false))

    Task {
      do {
        let reply = try await runCompletion(userMessage: trimmed)
        replacePlaceholder(id: placeholderID, with: reply, isLoading: false)
      } catch {
        removePlaceholder(id: placeholderID, isLoading: false)
        errorMessage = error.localizedDescription
      }
    }
  }

  private func replacePlaceholder(id: UUID, with content: String, isLoading: Bool) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[index] = ChatMessage(content: content, isUser: false)
    self.isLoading = isLoading
  }

  private func removePlaceholder(id: UUID, isLoading: Bool) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    if messages[index].content.isEmpty {
      messages.remove(at: index)
    }
    self.isLoading = isLoading
  }

  /// Clears the chat transcript and rotates outbound session state.
  public func reset() {
    messages.removeAll()
    inputText = ""
    isLoading = false
    errorMessage = nil
    resetSession()

    journalDraft = ""
    journalStatus = nil
    journalError = nil
    pushNotificationError = nil
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
        throw AppError.server(
          "Unauthorized (401). Paste a minted JWT (three segments like eyJ… . … . …)—not jwt.secret or JSON from shape-tree-config. Chat uses the same token as Journal (Connection)."
        )
      }
      throw AppError.server("Server returned status \(statusCode)")
    }
  }

  private func runCompletion(userMessage: String) async throws -> String {
    let workingClient = try await ensureSession()
    guard let sid = sessionId else {
      throw AppError.server("No active session.")
    }

    let response = try await workingClient.runCompletion(
      path: .init(id: sid),
      body: .json(.init(message: userMessage))
    )

    switch response {
    case .ok(let ok):
      let result = try ok.body.json
      return result.assistant
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
        throw AppError.server(
          "Unauthorized (401). Paste a minted JWT (three segments like eyJ… . … . …)—not jwt.secret or config JSON. Same token as Journal (Connection)."
        )
      }
      throw AppError.server("Server returned status \(statusCode)")
    }
  }

  // MARK: - Journal endpoints

  public func refreshJournalSubjects() async {
    journalError = nil
    journalStatus = nil
    guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      journalError = "Enter a ShapeTree server URL first."
      return
    }

    isJournalWorking = true
    defer { isJournalWorking = false }

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
          journalError =
            "Unauthorized (401). Paste a minted JWT (starts with eyJ, two dots)—not jwt.secret or JSON from shape-tree-config.json. Mint with `swift run ShapeTreeClientCLI --mint-token` from apps/shape-tree (see README)."
        } else {
          journalError = "Unexpected status \(statusCode) while fetching subjects."
        }

      default:
        journalError = "Could not load journal subjects."
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

  public func appendJournalEntryUsingServer() async {
    let bodyText = journalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !bodyText.isEmpty else {
      journalError = "Write something before appending."
      return
    }
    guard !journalSelectedSubjectIDs.isEmpty else {
      journalError = "Select at least one subject."
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
        journalError = "Unexpected status \(code) while appending."

      default:
        journalError = "Unexpected append response."
      }
    } catch {
      journalError = error.localizedDescription
    }
  }

  /// Lists journal entry metadata for each day in the UTC-aligned span `[startDayKey, endDayKey]` (`yy-MM-dd`).
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
      throw AppError.server("Unexpected status \(code) while listing journal entries.")
    }
  }

  /// Loads Markdown for `journal_day` (`yy-MM-dd`), or nil when the server reports no file.
  public func fetchJournalEntryDetailIfPresent(dayKey: String) async throws -> Components.Schemas.JournalEntryDetailResponse?
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
      throw AppError.server("Unexpected status \(code) while loading journal entry.")
    }
  }

  // MARK: - Push → `/devices/register-token`

  /// Registers an APNs device token with the ShapeTree server (JSON on disk), mirroring Scribe's automatic flow.
  public func sendPushDeviceToken(_ hexToken: String) async {
    pushNotificationError = nil

    guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      pushNotificationError = "Set a server URL before registering for push."
      return
    }

    let token = hexToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      pushNotificationError = "Empty device token."
      return
    }

    let deviceId = Self.stableDeviceIdentifier()

    do {
      let remote = try makeClient()
      let response = try await remote.registerDeviceToken(
        Operations.registerDeviceToken.Input(
          body: .json(.init(device_token: token, device_id: deviceId))
        )
      )

      switch response {
      case .ok(let packet):
        let body = try packet.body.json
        if !body.stored {
          pushNotificationError = "Server did not acknowledge device token storage."
        }

      case .badRequest(let err):
        let body = try err.body.json
        pushNotificationError = body.error.message

      case .internalServerError(let err):
        let body = try err.body.json
        pushNotificationError = body.error.message

      case .undocumented(let code, _):
        pushNotificationError = "Unexpected status \(code) while registering token."
      }
    } catch {
      pushNotificationError = error.localizedDescription
    }
  }

  private static let deviceDefaultsKey = "device_id"

  private static func stableDeviceIdentifier() -> String {
    if let saved = UserDefaults.standard.string(forKey: deviceDefaultsKey) {
      return saved
    }
    let newId = UUID().uuidString
    UserDefaults.standard.set(newId, forKey: deviceDefaultsKey)
    return newId
  }
}

// MARK: - Chat models

/// A lightweight chat transcript row used by SwiftUI previews.
public struct ChatMessage: Identifiable, Equatable {
  public let id: UUID
  public let content: String
  public let isUser: Bool

  public init(id: UUID = UUID(), content: String, isUser: Bool) {
    self.id = id
    self.content = content
    self.isUser = isUser
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
