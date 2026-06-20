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
  authCache: JWTAuthCache = JWTAuthCache(),
  log: Logger,
  llmURL: String,
  agentModel: String,
  systemPrompt: String,
  llmToken: String?,
  contextWindow: Int,
  contextWindowThreshold: Double,
  workingDirectory: String,
  otel: OtelSettings? = nil
) throws -> Router<BasicRequestContext> {
  let router = Router(context: BasicRequestContext.self)

  if let otel, !otel.disabled {
    _ = PrometheusMetrics.registry
    router.addMiddleware {
      TracingMiddleware()
      MetricsMiddleware()
    }
  }

  router.add(
    middleware: ShapeTreeJWTAuthMiddleware(store: authorizedKeys, replayCache: replayCache, authCache: authCache))

  let handler = ShapeTreeHandler(
    store: store,
    journalStore: journalStore,
    log: log,
    llmURL: llmURL,
    agentModel: agentModel,
    systemPrompt: systemPrompt,
    llmToken: llmToken,
    contextWindow: contextWindow,
    contextWindowThreshold: contextWindowThreshold,
    workingDirectory: workingDirectory)

  try handler.registerHandlers(on: router)
  return router
}
