import Configuration
import Foundation
import Hummingbird
import Logging

let log = Logger(label: "shape-tree.server")

// MARK: - Config key bindings

enum Key {
  static let serverPort: ConfigKey = "server.port"
  static let dataPath: ConfigKey = "data.path"
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
let dataPathRaw = try await reader.fetchRequiredString(forKey: Key.dataPath)

// MARK: Data root + journal repo (`git init` only — first append creates `HEAD`)

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resolvedDataRoot = ShapeTreeDataLayout.resolveDataRoot(rawPath: dataPathRaw, cwd: cwd)
let layout = ShapeTreeDataLayout(dataRoot: resolvedDataRoot)
try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)

let journalService = JournalService(layout: layout, log: log)
try await journalService.initializeJournalGitRepoIfNeeded()
let journalQuery = JournalQueryService(layout: layout, log: log)

let authorizedKeys = AuthorizedKeysStore(directory: layout.authorizedKeysDirectory)

// MARK: - Start server

let bearerToken: String? = ollamaToken.isEmpty ? nil : ollamaToken

let store = SessionStore()
let router = buildRoutes(
  store: store,
  journalService: journalService,
  journalQuery: journalQuery,
  authorizedKeys: authorizedKeys,
  log: log,
  defaultOllamaURL: ollamaURL,
  agentModel: agentModel,
  systemPrompt: systemPrompt,
  bearerToken: bearerToken,
  contextWindow: contextWindow,
  contextWindowThreshold: contextWindowThreshold,
  workingDirectory: resolvedDataRoot.path
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
  data_root=\(layout.dataRoot.path) \
  authorized_keys=\(layout.authorizedKeysDirectory.path) \
  ollama=\(ollamaURL) \
  model=\(agentModel)
  """)

try await app.run()
