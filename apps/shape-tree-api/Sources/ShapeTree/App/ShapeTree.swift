import Configuration
import Foundation
import Hummingbird
import Logging

@main
enum ShapeTree {
  static func main() async throws {
    let log = Logger(label: "shape-tree.server")
    let configPath = "shape-tree-config.json"

    let fileProvider = try await FileProvider<JSONSnapshot>(filePath: .init(configPath))
    let reader = ConfigReader(providers: [fileProvider])

    let port = try await reader.fetchRequiredInt(forKey: ConfigKeys.serverPort)
    let host = try await reader.fetchRequiredString(forKey: ConfigKeys.serverHost)
    let ollamaURL = try await reader.fetchRequiredString(forKey: ConfigKeys.ollamaURL)
    let ollamaToken = try await reader.fetchRequiredString(forKey: ConfigKeys.ollamaToken)
    let agentModel = try await reader.fetchRequiredString(forKey: ConfigKeys.agentModel)
    let systemPrompt = try await reader.fetchRequiredString(forKey: ConfigKeys.systemPrompt)
    let contextWindow = try await reader.fetchRequiredInt(forKey: ConfigKeys.contextWindow)
    let contextWindowThreshold = try await reader.fetchRequiredDouble(forKey: ConfigKeys.contextWindowThreshold)
    let dataPathRaw = try await reader.fetchRequiredString(forKey: ConfigKeys.dataPath)

    let journalCommitFallbackName = try await reader.fetchRequiredString(
      forKey: ConfigKeys.journalCommitAuthorName)
    let journalCommitFallbackEmail = try await reader.fetchRequiredString(
      forKey: ConfigKeys.journalCommitAuthorEmail)

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
    let authCache = JWTAuthCache(log: log)

    let store = SessionStore()
    let router = try buildRoutes(
      store: store,
      journalStore: journalStore,
      authorizedKeys: authorizedKeys,
      replayCache: replayCache,
      authCache: authCache,
      log: log,
      llmURL: ollamaURL,
      agentModel: agentModel,
      systemPrompt: systemPrompt,
      llmToken: ollamaToken,
      contextWindow: contextWindow,
      contextWindowThreshold: contextWindowThreshold,
      workingDirectory: resolvedDataRoot.path
    )

    let app = Application(
      router: router,
      configuration: .init(address: .hostname(host, port: port)))

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
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
