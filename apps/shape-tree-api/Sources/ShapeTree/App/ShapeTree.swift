import Configuration
import Foundation
import Hummingbird
import Logging
import NIOCore

@main
enum ShapeTree {
  static func main() async throws {
    let log = Logger(label: "shape-tree.server")
    let config = ConfigReader(providers: [
      EnvironmentVariablesProvider(),
      try await EnvironmentVariablesProvider(
        environmentFilePath: ".env",
        allowMissing: true
      ),
    ])

    let host = try config.requiredString(forKey: "HOST")
    let port = try config.requiredInt(forKey: "PORT")
    let adminHost = try config.requiredString(forKey: "ADMIN_HOST")
    let adminPort = try config.requiredInt(forKey: "ADMIN_PORT")
    let dataPathRaw = try config.requiredString(forKey: "DATA_PATH")
    let ollamaURL = try config.requiredString(forKey: "OLLAMA_URL")
    let ollamaToken = try config.requiredString(forKey: "OLLAMA_TOKEN")
    let agentModel = try config.requiredString(forKey: "AGENT_MODEL")
    let systemPrompt = try config.requiredString(forKey: "AGENT_SYSTEM_PROMPT")
    let contextWindow = try config.requiredInt(forKey: "AGENT_CONTEXT_WINDOW")
    let contextWindowThreshold = try config.requiredDouble(forKey: "AGENT_CONTEXT_WINDOW_THRESHOLD")
    let journalCommitFallbackName = try config.requiredString(forKey: "JOURNAL_COMMIT_AUTHOR_NAME")
    let journalCommitFallbackEmail = try config.requiredString(forKey: "JOURNAL_COMMIT_AUTHOR_EMAIL")
    let otel = try OtelSettings.load(from: config)

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
      workingDirectory: resolvedDataRoot.path,
      otel: otel
    )

    var app = Application(
      router: router,
      configuration: .init(
        address: .hostname(host, port: port),
        serverName: "ShapeTree"
      ),
      logger: log
    )

    _ = PrometheusMetrics.registry

    let adminApp = buildAdminApplication(
      host: adminHost,
      port: adminPort,
      serviceName: otel.serviceName,
      logger: app.logger
    )
    app.addServices(adminApp)

    if !otel.disabled {
      app.addServices(try OtelTracing.bootstrap(settings: otel, logger: app.logger))
    }

    app.logger.info(
      """
      event=server.start \
      address=\(host):\(port) \
      admin=\(adminHost):\(adminPort) \
      data_root=\(layout.dataRoot.path) \
      authorized_keys=\(layout.authorizedKeysDirectory.path) \
      ollama=\(ollamaURL) \
      model=\(agentModel) \
      otel_disabled=\(otel.disabled)
      """)

    if host == "0.0.0.0" {
      app.logger.warning(
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
