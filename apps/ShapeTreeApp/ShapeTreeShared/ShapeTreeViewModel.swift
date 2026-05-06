import Foundation
import OpenAPIAsyncHTTPClient
import ShapeTreeClient
import SwiftUI

/// View model for the ShapeTree chat UI.
///
/// Uses the OpenAPI-generated ``Client`` to talk to a local ShapeTree server
/// (default: `http://127.0.0.1:42069`).
@Observable
@MainActor
public final class ShapeTreeViewModel {

  // MARK: - Published state

  public var messages: [ChatMessage] = []
  public var inputText: String = ""
  public var isLoading: Bool = false
  public var errorMessage: String? = nil

  // MARK: - Configuration

  public var serverURL: String {
    didSet { resetSession() }
  }

  // MARK: - Private

  private var client: Client?
  private var sessionId: String?
  private let transport: AsyncHTTPClientTransport

  // MARK: - Init

  public init(
    serverURL: String = "http://127.0.0.1:42069"
  ) {
    self.serverURL = serverURL
    self.transport = AsyncHTTPClientTransport()
  }

  // MARK: - Public API

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

  /// Clear the conversation and start a fresh session.
  public func reset() {
    messages.removeAll()
    inputText = ""
    isLoading = false
    errorMessage = nil
    resetSession()
  }

  // MARK: - Private helpers

  private func resetSession() {
    sessionId = nil
    client = nil
  }

  private func ensureSession() async throws -> Client {
    if let client, sessionId != nil {
      return client
    }

    guard let server = URL(string: serverURL) else {
      throw AppError.invalidURL(serverURL)
    }

    let newClient = Client(serverURL: server, transport: transport)

    let response = try await newClient.createSession(
      .init(body: .json(.init(model: "gemma4:e2b")))
    )

    switch response {
    case .ok(let ok):
      let session = try ok.body.json
      sessionId = session.id
      client = newClient
      return newClient
    case .badRequest(let err):
      let body = try err.body.json
      throw AppError.server(body.error.message)
    case .undocumented(let code, _):
      throw AppError.server("Server returned status \(code)")
    }
  }

  private func runCompletion(userMessage: String) async throws -> String {
    let c = try await ensureSession()
    guard let sid = sessionId else {
      throw AppError.server("No active session.")
    }

    let response = try await c.runCompletion(
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
    case .undocumented(let code, _):
      throw AppError.server("Server returned status \(code)")
    }
  }
}

// MARK: - Types

/// A simple chat message displayed in the UI.
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
