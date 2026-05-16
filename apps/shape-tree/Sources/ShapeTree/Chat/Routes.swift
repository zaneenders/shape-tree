import Foundation
import Hummingbird
import Logging
import OpenAPIHummingbird
import ShapeTreeClient

/// Hummingbird router with OpenAPI-generated handlers registered.
func buildRoutes(
  store: SessionStore,
  journalStore: JournalStore,
  authorizedKeys: AuthorizedKeysStore,
  replayCache: JWTReplayCache = JWTReplayCache(),
  log: Logger,
  defaultOllamaURL: String = "http://127.0.0.1:11434",
  agentModel: String = "gemma4:e2b",
  systemPrompt: String = "You are a helpful coding assistant.",
  bearerToken: String? = nil,
  contextWindow: Int = 131_072,
  contextWindowThreshold: Double = 0.85,
  workingDirectory: String = "/tmp"
) -> Router<BasicRequestContext> {
  let router = Router(context: BasicRequestContext.self)

  router.add(middleware: ShapeTreeJWTAuthMiddleware(store: authorizedKeys, replayCache: replayCache))

  let handler = ShapeTreeHandler(
    store: store,
    journalStore: journalStore,
    log: log,
    defaultOllamaURL: defaultOllamaURL,
    agentModel: agentModel,
    systemPrompt: systemPrompt,
    bearerToken: bearerToken,
    contextWindow: contextWindow,
    contextWindowThreshold: contextWindowThreshold,
    workingDirectory: workingDirectory)

  try! handler.registerHandlers(on: router)
  return router
}
