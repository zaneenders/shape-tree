import Foundation
import Hummingbird
import Logging

let log = Logger(label: "shape-tree.server")

// MARK: - LLM configuration (server owns this)

let ollamaURL = ProcessInfo.processInfo.environment["OLLAMA_URL"]
  ?? "http://127.0.0.1:11434"
let agentModel = ProcessInfo.processInfo.environment["SHAPETREE_MODEL"]
  ?? "gemma4:e2b"
let systemPrompt = ProcessInfo.processInfo.environment["SHAPETREE_SYSTEM_PROMPT"]
  ?? "You are a helpful coding assistant."
let bearerToken = ProcessInfo.processInfo.environment["OLLAMA_TOKEN"]
let contextWindow = ProcessInfo.processInfo.environment["SHAPETREE_CONTEXT_WINDOW"]
  .flatMap(Int.init) ?? 131_072
let contextWindowThreshold = ProcessInfo.processInfo.environment["SHAPETREE_CONTEXT_THRESHOLD"]
  .flatMap(Double.init) ?? 0.85

let store = SessionStore()
let router = buildRoutes(
  store: store,
  log: log,
  defaultOllamaURL: ollamaURL,
  agentModel: agentModel,
  systemPrompt: systemPrompt,
  bearerToken: bearerToken,
  contextWindow: contextWindow,
  contextWindowThreshold: contextWindowThreshold
)
let host = "0.0.0.0"
let port = 42069

let app = Application(
  router: router,
  configuration: .init(
    address: .hostname(host, port: port)
  )
)

log.info(
  """
  event=server.start \
  address=\(host):\(port) \
  ollama=\(ollamaURL) \
  model=\(agentModel)
  """)

try await app.run()
