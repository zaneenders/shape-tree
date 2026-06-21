import Configuration
import Foundation
import HTML
import HTMX
import Hummingbird
import Logging
import NIOCore
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
      privateDirectories: privateDirectories
    )
    let initial = store.indexPost ?? store.publishedPosts.first ?? fallbackIndexPost(slug: indexSlug)

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
      initial: initial,
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
    app.logger.info("Admin server listening on http://\(adminHost):\(adminPort)")
    app.logger.info("OpenTelemetry disabled=\(otel.disabled)")

    try await app.runService()
  }

  static func configureRouter(
    _ router: Router<AppRequestContext>,
    store: ContentStore,
    initial: Post,
    indexSlug: String,
    auth: AuthServices,
    rateLimiter: LoginRateLimiter = LoginRateLimiter()
  ) {
    router.get { _, _ in
      WebPages.shell(store: store, initial: initial).makeHTMLResponse()
    }

    router.get("posts/:slug") { request, context in
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug) else {
        throw HTTPError(.notFound)
      }
      if post.isLogin {
        return Response(
          status: .seeOther,
          headers: [.location: "/login"],
          body: .init())
      }
      if post.isPrivate, context.identity == nil {
        throw HTTPError(.notFound)
      }
      return WebPages.shell(store: store, initial: post).makeHTMLResponse()
    }

    router.get("htmx/content/nav") { request, context in
      try HTMX.requireRequest(request)
      return WebPages.navigation(
        store: store,
        isAuthenticated: context.identity != nil
      ).makeHTMLResponse()
    }

    router.get("htmx/content/index") { request, _ in
      try HTMX.requireRequest(request)
      let post = store.indexPost ?? fallbackIndexPost(slug: indexSlug)
      let fragment = WebPages.contentFragment(for: post, store: store)
      return htmlFragmentResponse(fragment)
    }

    router.get("htmx/content/posts/:slug") { request, context in
      try HTMX.requireRequest(request)
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug) else {
        throw HTTPError(.notFound)
      }
      if post.isLogin {
        throw HTTPError(.notFound)
      }
      if post.isPrivate, context.identity == nil {
        throw HTTPError(.notFound)
      }
      let fragment = WebPages.contentFragment(for: post, store: store)
      return htmlFragmentResponse(fragment)
    }

    AuthRoutes.addRoutes(
      to: router,
      auth: auth,
      rateLimiter: rateLimiter,
      siteTitle: store.siteTitle,
      loginPost: store.loginPost
    )

    ClientRoutes.register(on: router)
  }

  private static func parsePrivateDirectories(_ raw: String?) -> Set<String> {
    guard let raw else { return [] }
    let dirs = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    return Set(dirs.filter { !$0.isEmpty })
  }

  private static func htmlFragmentResponse(_ fragment: String) -> Response {
    Response(
      status: .ok,
      headers: [.contentType: "text/html; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: fragment))
    )
  }

  private static func fallbackIndexPost(slug: String) -> Post {
    Post(
      slug: slug,
      title: "ShapeTree Web",
      date: .distantPast,
      tags: [],
      excerpt: nil,
      bodyMarkdown: "",
      bodyHTML: "",
      relativePath: "",
      isIndex: true
    )
  }
}
