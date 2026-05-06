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
  let log: Logger
  let defaultOllamaURL: String
  let agentModel: String
  let systemPrompt: String
  let bearerToken: String?
  let contextWindow: Int
  let contextWindowThreshold: Double

  // MARK: POST /sessions

  func createSession(
    _ input: Operations.createSession.Input
  ) async throws -> Operations.createSession.Output {
    guard case let .json(body) = input.body else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Request body must be JSON.")
      )
      return .badRequest(.init(body: .json(error)))
    }

    let prompt = body.systemPrompt ?? systemPrompt

    let config = AgentConfig(
      agentModel: agentModel,
      contextWindow: contextWindow,
      contextWindowThreshold: contextWindowThreshold,
      serverURL: defaultOllamaURL,
      bearerToken: bearerToken
    )

    let tools: [any ScribeTool] = [
      ShellTool(),
      ReadFileTool(),
      WriteFileTool(),
      EditFileTool(),
    ]

    let agent = ScribeAgent(
      configuration: config,
      systemPrompt: prompt,
      tools: tools
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

  // MARK: POST /sessions/{id}/completions

  func runCompletion(
    _ input: Operations.runCompletion.Input
  ) async throws -> Operations.runCompletion.Output {
    // Path parameter id is a String (extracted from the URL).
    guard let sessionId = UUID(uuidString: input.path.id) else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Invalid or missing session id.")
      )
      return .badRequest(.init(body: .json(error)))
    }

    guard case let .json(body) = input.body else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Request body must be JSON.")
      )
      return .badRequest(.init(body: .json(error)))
    }

    guard var session = await store.get(sessionId) else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "Session not found.")
      )
      return .notFound(.init(body: .json(error)))
    }

    // Append the user message.
    session.messages.append(
      .init(
        role: .user,
        content: body.message,
        name: nil,
        toolCalls: nil,
        toolCallId: nil
      )
    )

    let turnLog = Logger(label: "scribe.agent.turn.\(sessionId)")
    _ = try await session.agent.runTurn(
      messages: &session.messages,
      log: turnLog,
      onEvent: { _ in }
    )

    // Persist updated messages.
    await store.setMessages(sessionId, messages: session.messages)

    guard let assistantText = ChatHistory.lastAssistantText(from: session.messages) else {
      let error = Components.Schemas.HTTPErrorResponse(
        error: .init(message: "No assistant response.")
      )
      return .internalServerError(.init(body: .json(error)))
    }

    log.info(
      """
      event=completion.end \
      session=\(sessionId) \
      assistant_chars=\(assistantText.count)
      """)

    let response = Components.Schemas.CompletionResponse(assistant: assistantText)
    return .ok(.init(body: .json(response)))
  }
}
