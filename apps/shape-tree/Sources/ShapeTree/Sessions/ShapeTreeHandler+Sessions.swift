import Foundation
import Logging
import OpenAPIRuntime
import ScribeCore
import ShapeTreeClient

extension ShapeTreeHandler {

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
      serverURL: llmURL,
      apiKey: llmToken,
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

  // MARK: POST /sessions/{id}/interrupt

  func interruptSession(
    _ input: Operations.interruptSession.Input
  ) async throws -> Operations.interruptSession.Output {
    guard let sessionId = UUID(uuidString: input.path.id) else {
      return .badRequest(.init(body: .json(Self.errorBody("Invalid or missing session id."))))
    }
    guard await store.get(sessionId) != nil else {
      return .notFound(.init(body: .json(Self.errorBody("Session not found."))))
    }
    await store.interrupt(sessionId)
    log.debug("event=session.interrupt id=\(sessionId)")
    return .noContent(.init())
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

          switch result.outcome {
          case .completed:
            if assistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              continuation.yield(
                .init(kind: .harness_error, harness_error_message: "No assistant response."))
              continuation.finish()
              return
            }
          case .interrupted, .toolRoundLimit:
            break
          }

          log.info(
            "event=completion.stream.end session=\(sessionId) outcome=\(result.outcome) assistant_chars=\(assistantText.count)"
          )

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
}
