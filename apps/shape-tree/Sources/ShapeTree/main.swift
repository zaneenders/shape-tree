import Configuration
import Foundation
import Hummingbird
import Logging

let log = Logger(label: "shape-tree.server")

// MARK: - Config key bindings

enum Key {
  static let serverPort: ConfigKey = "server.port"
  static let ollamaURL: ConfigKey = "ollama.url"
  static let ollamaToken: ConfigKey = "ollama.token"
  static let agentModel: ConfigKey = "agent.model"
  static let systemPrompt: ConfigKey = "agent.systemPrompt"
  static let contextWindow: ConfigKey = "agent.contextWindow"
  static let contextWindowThreshold: ConfigKey = "agent.contextWindowThreshold"
}

// MARK: - Load configuration

let configPath = "shape-tree-config.json"

let fileProvider = try await FileProvider<JSONSnapshot>(filePath: .init(configPath))
let reader = ConfigReader(providers: [fileProvider])

let port = try await reader.fetchRequiredInt(forKey: Key.serverPort)
let ollamaURL = try await reader.fetchRequiredString(forKey: Key.ollamaURL)
let ollamaToken = try await reader.fetchRequiredString(forKey: Key.ollamaToken)
let agentModel = try await reader.fetchRequiredString(forKey: Key.agentModel)
let systemPrompt = try await reader.fetchRequiredString(forKey: Key.systemPrompt)
let contextWindow = try await reader.fetchRequiredInt(forKey: Key.contextWindow)
let contextWindowThreshold = try await reader.fetchRequiredDouble(forKey: Key.contextWindowThreshold)

// MARK: - Start server

let bearerToken: String? = ollamaToken.isEmpty ? nil : ollamaToken

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
