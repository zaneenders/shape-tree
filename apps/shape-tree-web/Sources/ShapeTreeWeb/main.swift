import Configuration
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdCompression
import Logging
import ShapeTreeConfig
import ShapeTreeMarkdown
import ShapeTreeWebAuth
import ShapeTreeWebBuilder

enum StartupError: Error {
  case missingBootstrap(path: String)
  case authMisconfigured
}

let logger = Logger(label: "ShapeTreeWeb")

do {
  try await runShapeTreeWeb(logger: logger)
} catch {
  logger.error("Startup failed", metadata: ["error": "\(error)"])
  if let data = "error: \(error)\n".data(using: .utf8) {
    try? FileHandle.standardError.write(contentsOf: data)
  }
  exit(1)
}

private func runShapeTreeWeb(logger: Logger) async throws {
  let packageRoot = PackageConfig.packageRoot(fromFilePath: #filePath)
  let config = try await PackageConfig.reader(packageRoot: packageRoot)

  let settings = try await AppSettings.load(packageRoot: packageRoot)
  let otel = try OtelSettings.load(from: config)

  if !settings.skipShapeTreeWebBuild {
    try await ShapeTreeWebBuilder.run(packageRoot: packageRoot)
  }

  let js = "\(settings.staticRoot)/app.js"
  let css = "\(settings.staticRoot)/app.css"
  let appjs = try String(contentsOfFile: js, encoding: .utf8)
  let styles = try String(contentsOfFile: css, encoding: .utf8)

  guard !appjs.isEmpty else {
    throw StartupError.missingBootstrap(path: js)
  }
  guard !styles.isEmpty else {
    throw StartupError.missingBootstrap(path: css)
  }

  guard
    let authBundle = try await AuthServices.bootstrapIfConfigured(
      from: config,
      siteURL: settings.siteURL,
      logger: logger)
  else {
    throw StartupError.authMisconfigured
  }

  let router = Router(context: AppRequestContext.self)

  if !otel.disabled {
    _ = PrometheusMetrics.registry
    router.addMiddleware {
      TracingMiddleware()
      MetricsMiddleware()
    }
  }

  AuthRoutes.addSessionMiddleware(to: router, auth: authBundle.services)

  router.addMiddleware {
    LogRequestsMiddleware(.info)
  }

  router.addMiddleware {
    ResponseCompressionMiddleware(minimumResponseSizeToCompress: 512)
  }

  AuthRoutes.addRoutes(
    to: router,
    auth: authBundle.services,
    rateLimiter: LoginRateLimiter(),
    spaLoginPage: { next in AuthPages.login(next: next) },
    spaVerifyPage: { token, next in AuthPages.verify(token: token, next: next) },
    spaCheckEmailPage: { AuthPages.checkEmail() }
  )

  router.get { _, _ in
    EditedResponse(
      headers: [.contentType: "text/html; charset=utf-8"],
      response: WebAssets.indexHTML(styles: styles, bootstrapScript: appjs)
    )
  }

  router.get("api/message") { _, _ in
    Message(message: "Hello from Hummingbird!", server: "Swift 6.3")
  }

  router.get("api/session") { _, context in
    SessionInfo(
      authenticated: context.identity != nil,
      email: context.identity?.email
    )
  }

  let articlePath = "\(settings.staticRoot)/article.md"
  router.get("api/article") { _, _ in
    try loadArticleDocument(from: URL(fileURLWithPath: articlePath))
  }

  FitProtectedRoutes.register(on: router, staticRoot: settings.staticRoot)

  router.addMiddleware {
    FileMiddleware(settings.staticRoot)
  }

  var app = Application(
    router: router,
    configuration: .init(
      address: .hostname(settings.hostname, port: settings.port),
      serverName: otel.serviceName
    ),
    logger: logger
  )

  _ = PrometheusMetrics.registry

  let adminApp = buildAdminApplication(
    host: settings.adminHost,
    port: settings.adminPort,
    serviceName: otel.serviceName,
    logger: logger
  )
  app.addServices(adminApp)

  authBundle.addServices(to: &app)
  let startupLogger = app.logger
  app.beforeServerStarts {
    try await authBundle.runStartupTasks(logger: startupLogger)
  }

  if !otel.disabled {
    app.addServices(try OtelTracing.bootstrap(settings: otel, logger: logger))
  }

  logger.info(
    """
    event=server.start \
    address=\(settings.hostname):\(settings.port) \
    admin=\(settings.adminHost):\(settings.adminPort) \
    static_root=\(settings.staticRoot) \
    site_url=\(settings.siteURL) \
    auth_enabled=\(authBundle != nil) \
    otel_disabled=\(otel.disabled)
    """)

  try await app.runService()
}

private struct Message: ResponseEncodable {
  let message: String
  let server: String
}

private struct SessionInfo: ResponseEncodable {
  let authenticated: Bool
  let email: String?
}

extension ArticleDocument: ResponseEncodable {}
