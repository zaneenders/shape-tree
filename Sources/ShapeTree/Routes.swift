import Foundation
import Hummingbird
import Logging
import ScribeCore

// MARK: - Request / Response types

struct CreateSessionRequest: Decodable, Sendable {
  let model: String
  let serverURL: String
  let systemPrompt: String
  let bearerToken: String?
  let contextWindow: Int?
  let contextWindowThreshold: Double?
}

struct CreateSessionResponse: ResponseCodable, Sendable {
  let id: UUID
  let createdAt: Date
}

struct CompletionRequest: Decodable, Sendable {
  let message: String
}

struct CompletionResponse: ResponseCodable, Sendable {
  let assistant: String
}

struct ErrorResponse: ResponseCodable, Sendable {
  let ok: Bool
  let error: String
}

// MARK: - Route setup

func buildRoutes(store: SessionStore, log: Logger) -> Router<BasicRequestContext> {
  let router = Router(context: BasicRequestContext.self)

  // MARK: POST /sessions — create a new agent session
  router.post("/sessions") { request, context -> CreateSessionResponse in
    let body = try await request.decode(as: CreateSessionRequest.self, context: context)

    guard let serverURL = URL(string: body.serverURL),
      let scheme = serverURL.scheme,
      scheme == "http" || scheme == "https"
    else {
      throw HTTPError(
        .badRequest, message: "Invalid serverURL (must be http or https): \(body.serverURL)"
      )
    }

    let config = AgentConfig(
      agentModel: body.model,
      contextWindow: body.contextWindow ?? 131_072,
      contextWindowThreshold: body.contextWindowThreshold ?? 0.85,
      serverURL: body.serverURL,
      bearerToken: body.bearerToken
    )

    let tools: [any ScribeTool] = [
      ShellTool(),
      ReadFileTool(),
      WriteFileTool(),
      EditFileTool(),
    ]

    let agent = ScribeAgent(
      configuration: config,
      systemPrompt: body.systemPrompt,
      tools: tools
    )

    let id = await store.create(agent: agent, systemPrompt: body.systemPrompt)

    log.info(
      """
      event=session.create \
      id=\(id) \
      model=\(body.model) \
      server=\(body.serverURL)
      """)

    // Resolve createdAt from the store entry
    let session = await store.get(id)
    return CreateSessionResponse(id: id, createdAt: session?.createdAt ?? Date())
  }

  // MARK: POST /sessions/:id/completions — run one completion turn
  router.post("/sessions/{id}/completions") { request, context -> CompletionResponse in
    guard let idString = context.parameters.get("id"),
      let sessionId = UUID(uuidString: idString)
    else {
      throw HTTPError(.badRequest, message: "Invalid or missing session id.")
    }

    let body = try await request.decode(as: CompletionRequest.self, context: context)

    guard var session = await store.get(sessionId) else {
      throw HTTPError(.notFound, message: "Session not found.")
    }

    // Append the user message
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

    // Persist updated messages
    await store.setMessages(sessionId, messages: session.messages)

    guard let assistantText = ChatHistory.lastAssistantText(from: session.messages) else {
      throw HTTPError(.internalServerError, message: "No assistant response.")
    }

    log.info(
      """
      event=completion.end \
      session=\(sessionId) \
      assistant_chars=\(assistantText.count)
      """)

    return CompletionResponse(assistant: assistantText)
  }

  return router
}
