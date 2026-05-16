import Configuration
import Foundation
import Hummingbird
import Logging

let log = Logger(label: "shape-tree.server")

enum Key {
  static let serverHost: ConfigKey = "server.host"
  static let serverPort: ConfigKey = "server.port"
  static let dataPath: ConfigKey = "data.path"
  static let ollamaURL: ConfigKey = "ollama.url"
  static let ollamaToken: ConfigKey = "ollama.token"
  static let agentModel: ConfigKey = "agent.model"
  static let systemPrompt: ConfigKey = "agent.systemPrompt"
  static let contextWindow: ConfigKey = "agent.contextWindow"
  static let contextWindowThreshold: ConfigKey = "agent.contextWindowThreshold"
  static let journalCommitAuthorName: ConfigKey = "journal.commitAuthor.name"
  static let journalCommitAuthorEmail: ConfigKey = "journal.commitAuthor.email"
}

let configPath = "shape-tree-config.json"

let fileProvider = try await FileProvider<JSONSnapshot>(filePath: .init(configPath))
let reader = ConfigReader(providers: [fileProvider])

let port = try await reader.fetchRequiredInt(forKey: Key.serverPort)
let host = try await reader.fetchRequiredString(forKey: Key.serverHost)
let ollamaURL = try await reader.fetchRequiredString(forKey: Key.ollamaURL)
let ollamaToken = try await reader.fetchRequiredString(forKey: Key.ollamaToken)
let agentModel = try await reader.fetchRequiredString(forKey: Key.agentModel)
let systemPrompt = try await reader.fetchRequiredString(forKey: Key.systemPrompt)
let contextWindow = try await reader.fetchRequiredInt(forKey: Key.contextWindow)
let contextWindowThreshold = try await reader.fetchRequiredDouble(forKey: Key.contextWindowThreshold)
let dataPathRaw = try await reader.fetchRequiredString(forKey: Key.dataPath)

let journalCommitFallbackName = try await reader.fetchRequiredString(forKey: Key.journalCommitAuthorName)
let journalCommitFallbackEmail = try await reader.fetchRequiredString(forKey: Key.journalCommitAuthorEmail)

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resolvedDataRoot = ShapeTreeDataLayout.resolveDataRoot(rawPath: dataPathRaw, cwd: cwd)
let layout = ShapeTreeDataLayout(dataRoot: resolvedDataRoot)
try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)

let journalStore = JournalStore(
  layout: layout,
  log: log,
  fallbackCommitAuthorName: journalCommitFallbackName,
  fallbackCommitAuthorEmail: journalCommitFallbackEmail)
try await journalStore.initializeJournalGitRepoIfNeeded()

let authorizedKeys = AuthorizedKeysStore(directory: layout.authorizedKeysDirectory)
let replayCache = JWTReplayCache()

let bearerToken: String? = ollamaToken.isEmpty ? nil : ollamaToken

let store = SessionStore()
let router = buildRoutes(
  store: store,
  journalStore: journalStore,
  authorizedKeys: authorizedKeys,
  replayCache: replayCache,
  log: log,
  defaultOllamaURL: ollamaURL,
  agentModel: agentModel,
  systemPrompt: systemPrompt,
  bearerToken: bearerToken,
  contextWindow: contextWindow,
  contextWindowThreshold: contextWindowThreshold,
  workingDirectory: resolvedDataRoot.path
)

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

if host == "0.0.0.0" {
  log.warning(
    """
    event=server.lan_bind_warning \
    message="server.host=0.0.0.0 exposes the listener on every interface; \
    pair with TLS and a network ACL or restrict to 127.0.0.1"
    """)
}

try await app.run()

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
