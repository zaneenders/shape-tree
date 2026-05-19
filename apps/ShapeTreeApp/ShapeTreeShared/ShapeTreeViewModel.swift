import Foundation
import NodeTreeAPI
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import ShapeTreeClient
import SwiftUI

@Observable
@MainActor
public final class ShapeTreeViewModel {

  private static let unauthorizedMessage =
    "Unauthorized (401). This device's public key isn't enrolled on the server. Tap the network icon to copy the public JWK, then drop it into the server's authorized_keys/<kid>.jwk."

  private static let serverOfflineMessage = "Server is offline."

  /// The single mapping for HTTP statuses without a typed `case`. 401 always means
  /// "device not enrolled" because this API requires bearer auth on every route.
  private static func messageForStatus(_ code: Int, fallback: String) -> String {
    code == 401 ? unauthorizedMessage : fallback
  }

  /// Pulls the operator-facing message off an `HTTPErrorResponse` body decoder.
  private static func httpErrorLine(
    _ decode: () throws -> ShapeTreeClient.Components.Schemas.HTTPErrorResponse
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

  public typealias TodoItem = NodeTreeAPI.Components.Schemas.TodoItem

  public var todoItems: [TodoItem] = []
  public var todoError: String? = nil
  public var todoStatus: String? = nil
  public var isTodoWorking: Bool = false

  public var serverURL: String {
    didSet {
      connectionMonitor.serverURLDidChange(serverURL)
      invalidateOpenAPIClientAndAgentSession()
      journalSubjects.removeAll()
      journalStatus = nil
      journalError = nil
      journalCalendarError = nil
      journalSelectedSubjectIDs = []
      todoItems.removeAll()
      todoStatus = nil
      todoError = nil
    }
  }

  public let keyStore: ShapeTreeKeyStore
  public let connectionMonitor: ConnectionMonitor

  public var connectionState: ConnectionState { connectionMonitor.state }
  public var isOnline: Bool { connectionState == .online }

  private var offlineOrUnauthorizedMessage: String {
    connectionState == .unauthorized ? Self.unauthorizedMessage : Self.serverOfflineMessage
  }

  /// Shared generated client — same bearer middleware stack for journal and chat paths.
  private var sharedOpenAPIClient: ShapeTreeClient.Client?
  private var sharedTodoClient: NodeTreeAPI.Client?
  private var sessionId: String?
  private let transport: AsyncHTTPClientTransport

  public init(
    serverURL: String,
    keyStore: ShapeTreeKeyStore = ShapeTreeKeyStore()
  ) {
    self.transport = AsyncHTTPClientTransport()
    self.keyStore = keyStore
    self.serverURL = serverURL
    self.connectionMonitor = ConnectionMonitor(serverURL: serverURL, keyStore: keyStore)
    _ = try? keyStore.loadOrGenerate()
  }

  private func bearerMiddlewares() -> [any ClientMiddleware] {
    let store = keyStore
    return [
      BearerAuthClientMiddleware(tokenProvider: { @Sendable in
        try await MainActor.run { try store.mintES256JWT(ttl: 900) }
      })
    ]
  }

  private func makeClient() throws -> ShapeTreeClient.Client {
    guard let endpoint = URL(string: serverURL) else {
      throw AppError.invalidURL(serverURL)
    }
    return ShapeTreeClient.Client(
      serverURL: endpoint, transport: transport, middlewares: bearerMiddlewares())
  }

  private func makeTodoClient() throws -> NodeTreeAPI.Client {
    guard let endpoint = URL(string: serverURL) else {
      throw AppError.invalidURL(serverURL)
    }
    return NodeTreeAPI.Client(
      serverURL: endpoint, transport: transport, middlewares: bearerMiddlewares())
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
    guard connectionState == .online else {
      errorMessage = offlineOrUnauthorizedMessage
      return
    }

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

  public func interruptAgentTurn() async {
    guard isLoading, let sid = sessionId else { return }
    errorMessage = nil
    do {
      let client = try openAPIClient()
      let response = try await client.interruptSession(path: .init(id: sid))
      switch response {
      case .noContent:
        isLoading = false
      case .badRequest(let err):
        errorMessage = try Self.httpErrorLine { try err.body.json }
      case .notFound:
        invalidateAgentSessionOnly()
        errorMessage = "Session expired. Please try again."
      case .undocumented(let statusCode, _):
        errorMessage = Self.messageForStatus(
          statusCode, fallback: "Server returned status \(statusCode)")
      }
    } catch {
      errorMessage = error.localizedDescription
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

  private func openAPIClient() throws -> ShapeTreeClient.Client {
    if let client = sharedOpenAPIClient {
      return client
    }
    let built = try makeClient()
    sharedOpenAPIClient = built
    return built
  }

  private func invalidateOpenAPIClientAndAgentSession() {
    sharedOpenAPIClient = nil
    sharedTodoClient = nil
    sessionId = nil
  }

  private func openTodoClient() throws -> NodeTreeAPI.Client {
    if let sharedTodoClient { return sharedTodoClient }
    let built = try makeTodoClient()
    sharedTodoClient = built
    return built
  }

  private static func todoHTTPErrorLine(
    _ decode: () throws -> NodeTreeAPI.Components.Schemas.HTTPErrorResponse
  ) rethrows -> String {
    try decode().error.message
  }

  private func invalidateAgentSessionOnly() {
    sessionId = nil
  }

  private func ensureSession() async throws -> ShapeTreeClient.Client {
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
      func appendStreamFragment(
        _ fragment: String, section: ShapeTreeClient.Components.Schemas.CompletionStreamSection
      ) {
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
            .init(
              kind: .toolCall(
                toolName: event.tool_name ?? "",
                arguments: event.tool_arguments ?? "",
                output: event.tool_output ?? "")))
          updateAssistantPlaceholder(id: placeholderID, blocks: blocks)

        case .turn_interrupted:
          blocks.append(.init(kind: .answer("(interrupted)")))
          updateAssistantPlaceholder(id: placeholderID, blocks: blocks)

        case .done:
          if event.outcome == .interrupted, !hasNonemptyAnswerBlock() {
            blocks.append(.init(kind: .answer("(interrupted)")))
          }
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
    guard connectionState == .online else { return }
    journalError = nil
    journalStatus = nil
    guard !serverURL.isEmpty else {
      journalError = "Enter a ShapeTree server URL first."
      return
    }

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
    guard !serverURL.isEmpty else {
      journalError = "Enter a ShapeTree server URL first."
      return false
    }
    guard connectionState == .online else {
      journalError = offlineOrUnauthorizedMessage
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
    guard connectionState == .online else {
      journalError = offlineOrUnauthorizedMessage
      return
    }

    journalError = nil
    journalStatus = nil
    isJournalWorking = true
    defer { isJournalWorking = false }

    do {
      let remote = try openAPIClient()
      let payload = ShapeTreeClient.Components.Schemas.AppendJournalEntryRequest(
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
    -> [ShapeTreeClient.Components.Schemas.JournalEntrySummary]
  {
    guard connectionState == .online else {
      throw AppError.server(offlineOrUnauthorizedMessage)
    }
    guard !serverURL.isEmpty else {
      throw AppError.server("Enter a ShapeTree server URL first.")
    }
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

  public func fetchJournalEntryDetailIfPresent(dayKey: String) async throws
    -> ShapeTreeClient.Components.Schemas.JournalEntryDetailResponse?
  {
    guard connectionState == .online else {
      throw AppError.server(offlineOrUnauthorizedMessage)
    }
    guard !serverURL.isEmpty else {
      throw AppError.server("Enter a ShapeTree server URL first.")
    }
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

  // MARK: - Todo tree

  public var todoRootItem: TodoItem? {
    todoItems.first { item in
      if case .root = item.parent_id { return true }
      return false
    }
  }

  public func refreshTodoItems() async {
    guard connectionState == .online else {
      todoItems = []
      return
    }
    guard !serverURL.isEmpty else {
      todoError = "Enter a ShapeTree server URL first."
      return
    }

    todoError = nil
    todoStatus = nil
    isTodoWorking = true
    defer { isTodoWorking = false }

    do {
      let remote = try openTodoClient()
      let response = try await remote.listTodoItems(.init())

      switch response {
      case .ok(let packet):
        let payload = try packet.body.json
        todoItems = payload.items
        todoStatus = todoItems.isEmpty ? "No items yet." : "\(todoItems.count) items loaded."

      case .badRequest(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .internalServerError(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .unauthorized:
        todoError = Self.unauthorizedMessage

      case .undocumented(let statusCode, _):
        todoError = Self.messageForStatus(
          statusCode, fallback: "Unexpected status \(statusCode) while loading todos.")
      }
    } catch {
      todoError = error.localizedDescription
    }
  }

  public typealias TodoItemStatus = NodeTreeAPI.Components.Schemas.TodoItemStatus

  @discardableResult
  public func createTodoItem(
    title: String,
    parentID: NodeTreeAPI.Components.Schemas.ParentId = .root(.init(kind: .root)),
    steps: [String]? = nil
  ) async -> TodoItem? {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      todoError = "Enter a title before adding."
      return nil
    }
    guard connectionState == .online else {
      todoError = offlineOrUnauthorizedMessage
      return nil
    }
    guard !serverURL.isEmpty else {
      todoError = "Enter a ShapeTree server URL first."
      return nil
    }

    let stepPayloads = steps?
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .map { NodeTreeAPI.Components.Schemas.BreakDownStep(title: $0) }

    todoError = nil
    isTodoWorking = true
    defer { isTodoWorking = false }

    do {
      let remote = try openTodoClient()
      let response = try await remote.createTodoItem(
        body: .json(
          .init(
            title: trimmed,
            parent_id: parentID,
            steps: stepPayloads?.isEmpty == false ? stepPayloads : nil
          ))
      )

      switch response {
      case .created(let packet):
        let created = try packet.body.json
        await refreshTodoItems()
        todoStatus = "Added \"\(trimmed)\"."
        return created

      case .badRequest(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .notFound(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .internalServerError(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .unauthorized:
        todoError = Self.unauthorizedMessage

      case .undocumented(let statusCode, _):
        todoError = Self.messageForStatus(
          statusCode, fallback: "Unexpected status \(statusCode) while creating todo.")
      }
    } catch {
      todoError = error.localizedDescription
    }
    return nil
  }

  @discardableResult
  public func breakDownTodoItem(id: String, stepTitles: [String]) async -> [TodoItem]? {
    let steps = stepTitles
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard !steps.isEmpty else {
      todoError = "Add at least one step."
      return nil
    }
    guard connectionState == .online else {
      todoError = offlineOrUnauthorizedMessage
      return nil
    }
    guard !serverURL.isEmpty else {
      todoError = "Enter a ShapeTree server URL first."
      return nil
    }

    todoError = nil
    isTodoWorking = true
    defer { isTodoWorking = false }

    do {
      let remote = try openTodoClient()
      let response = try await remote.breakDownTodoItem(
        path: .init(itemId: id),
        body: .json(.init(steps: steps.map { .init(title: $0) }))
      )

      switch response {
      case .created(let packet):
        let payload = try packet.body.json
        await refreshTodoItems()
        todoStatus = "Added \(steps.count) subtask\(steps.count == 1 ? "" : "s")."
        return payload.items

      case .badRequest(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .notFound(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .internalServerError(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .unauthorized:
        todoError = Self.unauthorizedMessage

      case .undocumented(let statusCode, _):
        todoError = Self.messageForStatus(
          statusCode, fallback: "Unexpected status \(statusCode) while breaking down todo.")
      }
    } catch {
      todoError = error.localizedDescription
    }
    return nil
  }

  @discardableResult
  public func updateTodoItem(
    id: String,
    title: String? = nil,
    status: TodoItemStatus? = nil,
    notes: String? = nil
  ) async -> Bool {
    guard connectionState == .online else {
      todoError = offlineOrUnauthorizedMessage
      return false
    }
    guard !serverURL.isEmpty else {
      todoError = "Enter a ShapeTree server URL first."
      return false
    }

    todoError = nil
    isTodoWorking = true
    defer { isTodoWorking = false }

    do {
      let remote = try openTodoClient()
      let response = try await remote.updateTodoItem(
        path: .init(itemId: id),
        body: .json(.init(title: title, status: status, notes: notes))
      )

      switch response {
      case .ok(let packet):
        let updated = try packet.body.json
        if let index = todoItems.firstIndex(where: { $0.id == updated.id }) {
          todoItems[index] = updated
        } else {
          await refreshTodoItems()
        }
        return true

      case .badRequest(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .notFound(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .conflict(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .internalServerError(let err):
        todoError = try Self.todoHTTPErrorLine { try err.body.json }

      case .unauthorized:
        todoError = Self.unauthorizedMessage

      case .undocumented(let statusCode, _):
        todoError = Self.messageForStatus(
          statusCode, fallback: "Unexpected status \(statusCode) while updating todo.")
      }
    } catch {
      todoError = error.localizedDescription
    }
    return false
  }

  public func archiveTodoItem(_ item: TodoItem) async -> Bool {
    await updateTodoItem(id: item.id, status: .archive)
  }

  public func restoreTodoItem(_ item: TodoItem) async -> Bool {
    await updateTodoItem(id: item.id, status: .open)
  }

  public func toggleTodoCompleted(_ item: TodoItem) async {
    guard !ShapeTreeTodoTree.hasChildren(itemID: item.id, items: todoItems) else { return }
    guard item.status != .archive else { return }

    let isCompleted = item.status == .completed
    if !isCompleted,
      !ShapeTreeTodoTree.canMarkCompleted(itemID: item.id, items: todoItems)
    {
      todoError = "Finish or archive all subtasks before completing this item."
      return
    }

    let next: TodoItemStatus = isCompleted ? .open : .completed
    _ = await updateTodoItem(id: item.id, status: next)
  }
}
