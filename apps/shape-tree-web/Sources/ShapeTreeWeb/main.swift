import Configuration
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdCompression
import Logging
import NIOCore
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

  let authPages = AuthPages(styles: styles, bootstrapScript: appjs)

  let shellHTML = WebAssets.indexHTML(styles: styles, bootstrapScript: appjs)
  let spaShellPage: @Sendable () -> Response = {
    Response(
      status: .ok,
      headers: [.contentType: "text/html; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: shellHTML))
    )
  }

  AuthRoutes.addRoutes(
    to: router,
    auth: authBundle.services,
    rateLimiter: LoginRateLimiter(),
    spaShellPage: spaShellPage,
    spaVerifyPage: { token, next in authPages.verify(token: token, next: next) },
    spaCheckEmailPage: { authPages.checkEmail() }
  )

  router.get { _, _ in
    spaShellPage()
  }

  router.get("api/message") { _, _ in
    Message(message: "Hello from Hummingbird!", server: "Swift 6.3")
  }

  router.get("api/session") { _, context in
    let authenticated = context.identity != nil
    return SessionInfo(
      authenticated: authenticated,
      email: context.identity?.email,
      demo: true,
      fit: authenticated,
      article: true
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

  let otelApp = buildOTelApplication(
    host: settings.otelHost,
    port: settings.otelPort,
    serviceName: otel.serviceName,
    logger: logger
  )
  app.addServices(otelApp)

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
    otel=\(settings.otelHost):\(settings.otelPort) \
    static_root=\(settings.staticRoot) \
    site_url=\(settings.siteURL) \
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
  let demo: Bool
  let fit: Bool
  let article: Bool
}

extension ArticleDocument: ResponseEncodable {}
