import Configuration
import Foundation
import ShapeTreeWebAssets
import Hummingbird
import Logging
import ShapeTreeWebAuth
import ShapeTreeWebCore

@main
enum ShapeTreeWeb {
  static func main() async throws {
    let log = Logger(label: "shape-tree-web.server")

    let secretKeys = SecretsSpecifier<String, String>.specific([
      "PGPASSWORD", "SMTP_PASSWORD",
    ])
    let config = ConfigReader(providers: [
      EnvironmentVariablesProvider(secretsSpecifier: secretKeys),
      try await EnvironmentVariablesProvider(
        environmentFilePath: ".env",
        allowMissing: true,
        secretsSpecifier: secretKeys
      ),
    ])

    if let addUserIndex = CommandLine.arguments.firstIndex(of: "--add-user") {
      guard addUserIndex + 1 < CommandLine.arguments.count else {
        log.error("Usage: ShapeTreeWeb --add-user <email>")
        return
      }
      try await AuthCLI.addUser(
        email: CommandLine.arguments[addUserIndex + 1], logger: log)
      return
    }

    let host = try config.requiredString(forKey: "HOST")
    let port = try config.requiredInt(forKey: "PORT")
    let adminHost = try config.requiredString(forKey: "ADMIN_HOST")
    let adminPort = try config.requiredInt(forKey: "ADMIN_PORT")
    let contentPath = try config.requiredString(forKey: "CONTENT_PATH")
    let indexSlug = try config.requiredString(forKey: "INDEX_SLUG")
    let loginSlug = config.string(forKey: "LOGIN_SLUG", default: "Login")
    let otel = try OtelSettings.load(from: config)
    let siteURL = try config.requiredString(forKey: "SITE_URL")
    let privateDirectories = parsePrivateDirectories(
      config.string(forKey: "AUTH_PRIVATE_DIRECTORIES")
    )

    let authBundle = try await AuthServices.bootstrap(
      from: config, siteURL: siteURL, logger: log)

    let contentURL = URL(
      fileURLWithPath: contentPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    let store = try ContentStore(
      contentDirectory: contentURL,
      indexSlug: indexSlug,
      loginSlug: loginSlug,
      privateDirectories: privateDirectories
    )

    let router = Router(context: AppRequestContext.self)
    if !otel.disabled {
      _ = PrometheusMetrics.registry
      router.addMiddleware {
        TracingMiddleware()
        MetricsMiddleware()
      }
    }

    ShapeTreeWeb.configureRouter(
      router,
      store: store,
      indexSlug: indexSlug,
      auth: authBundle.services
    )

    var app = Application(
      router: router,
      configuration: .init(
        address: .hostname(host, port: port),
        serverName: "ShapeTreeWeb"
      ),
      logger: log
    )

    let adminApp = buildAdminApplication(
      host: adminHost,
      port: adminPort,
      serviceName: otel.serviceName,
      logger: app.logger
    )
    app.addServices(adminApp)
    authBundle.addServices(to: &app)

    let startupLogger = app.logger
    app.beforeServerStarts {
      try await authBundle.runStartupTasks(logger: startupLogger)
    }

    if !otel.disabled {
      app.addServices(try OtelTracing.bootstrap(settings: otel, logger: app.logger))
    }

    app.logger.info("Serving \(store.posts.count) markdown file(s) from \(contentURL.path)")
    if !privateDirectories.isEmpty {
      app.logger.info("Private directories: \(privateDirectories.sorted().joined(separator: ", "))")
    }
    app.logger.info("Listening on http://\(host):\(port)")
    if PostWasmAsset.isAvailable {
      app.logger.info("Embedded \(PostWasmAsset.availableSlugs.count) wasm post(s)")
    }
    app.logger.info("Admin server listening on http://\(adminHost):\(adminPort)")
    app.logger.info("OpenTelemetry disabled=\(otel.disabled)")

    try await app.runService()
  }
}
