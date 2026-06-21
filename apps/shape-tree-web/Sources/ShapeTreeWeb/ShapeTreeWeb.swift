import Configuration
import Foundation
import HTML
import HTMX
import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore
import PostgresNIO
import ShapeTreeWebCore

@main
enum ShapeTreeWeb {
  static func main() async throws {
    let log = Logger(label: "shape-tree-web.server")

    if let addUserIndex = CommandLine.arguments.firstIndex(of: "--add-user") {
      guard addUserIndex + 1 < CommandLine.arguments.count else {
        log.error("Usage: ShapeTreeWeb --add-user <email>")
        return
      }
      try await addUser(email: CommandLine.arguments[addUserIndex + 1], logger: log)
      return
    }

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

    let host = try config.requiredString(forKey: "HOST")
    let port = try config.requiredInt(forKey: "PORT")
    let adminHost = try config.requiredString(forKey: "ADMIN_HOST")
    let adminPort = try config.requiredInt(forKey: "ADMIN_PORT")
    let contentPath = try config.requiredString(forKey: "CONTENT_PATH")
    let indexSlug = try config.requiredString(forKey: "INDEX_SLUG")
    let otel = try OtelSettings.load(from: config)
    let siteURL = config.string(forKey: "SITE_URL") ?? "http://\(host):\(port)"
    let privateDirectories = parsePrivateDirectories(
      config.string(forKey: "AUTH_PRIVATE_DIRECTORIES")
    )

    let auth = try await buildAuthServices(from: config, siteURL: siteURL, logger: log)

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

    let sessionConfig = SessionMiddlewareConfiguration(
      sessionCookieParameters: .init(
        name: "SESSION_ID",
        secure: auth.services.secureCookies,
        sameSite: .lax
      ),
      defaultSessionExpiration: auth.services.settings.sessionTTL
    )
    router.addMiddleware {
      SessionMiddleware(storage: auth.services.persist, configuration: sessionConfig)
      SessionAuthenticator(context: AppRequestContext.self) {
        (userID: UUID, context: UserRepositoryContext) async throws -> User? in
        try await auth.services.database.user(id: userID, logger: context.logger)
      }
    }

    router.get { _, _ in
      WebPages.shell(store: store, initial: initial).makeHTMLResponse()
    }

    router.get("posts/:slug") { request, context in
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug), !post.isPrivate else {
        throw HTTPError(.notFound)
      }
      if post.isPrivate, context.identity == nil {
        return AuthMiddleware.unauthenticatedResponse(request: request, next: request.uri.path)
      }
      return WebPages.shell(store: store, initial: post).makeHTMLResponse()
    }

    router.get("htmx/content/nav") { request, _ in
      try HTMX.requireRequest(request)
      return WebPages.navigation(store: store).makeHTMLResponse()
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
      guard let post = store.post(slug: slug), !post.isPrivate else {
        throw HTTPError(.notFound)
      }
      if post.isPrivate, context.identity == nil {
        return AuthMiddleware.unauthenticatedResponse(request: request, next: "/posts/\(slug)")
      }
      let fragment = WebPages.contentFragment(for: post, store: store)
      return htmlFragmentResponse(fragment)
    }

    let rateLimiter = LoginRateLimiter()
    AuthRoutes.addRoutes(
      to: router,
      auth: auth.services,
      rateLimiter: rateLimiter,
      siteTitle: store.siteTitle
    )

    ClientRoutes.register(on: router)

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

    app.addServices(auth.postgresClient)
    let startupLogger = app.logger
    app.beforeServerStarts {
      try await Migrations.run(client: auth.postgresClient, logger: startupLogger)
      try await auth.services.database.deleteExpiredLoginTokens(logger: startupLogger)
      try await auth.persistDriver.tidyExpired()
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

  private static func addUser(email rawEmail: String, logger: Logger) async throws {
    let email = AuthMiddleware.normalizedEmail(rawEmail)
    guard email.contains("@") else {
      logger.error("Invalid email: \(rawEmail)")
      return
    }

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

    let postgresSettings = try PostgresSettings.load(from: config)
    let client = PostgresClient(configuration: postgresSettings.configuration)
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { await client.run() }
      try await Migrations.run(client: client, logger: logger)
      let database = PostgresAuthDatabase(client: client)
      if let existing = try await database.user(email: email, logger: logger) {
        logger.notice("User already exists: \(existing.email) (\(existing.id))")
      } else {
        let user = try await database.createUser(email: email, logger: logger)
        logger.notice("Added user: \(user.email) (\(user.id))")
      }
      group.cancelAll()
    }
  }

  private static func buildAuthServices(
    from config: ConfigReader,
    siteURL: String,
    logger: Logger
  ) async throws -> AuthServicesBundle {
    do {
      let postgresSettings = try PostgresSettings.load(from: config)
      let client = PostgresClient(configuration: postgresSettings.configuration)
      let authSettings = AuthSettings.load(from: config)
      let smtp = SMTPSettings.load(from: config)
      let secureCookies = URL(string: siteURL)?.scheme == "https"
      let privateDirectories = parsePrivateDirectories(
        config.string(forKey: "AUTH_PRIVATE_DIRECTORIES")
      )

      let persist = PostgresPersistDriver(client: client, logger: logger)
      let database = PostgresAuthDatabase(client: client)
      return AuthServicesBundle(
        services: AuthServices(
          database: database,
          persist: persist,
          settings: authSettings,
          smtp: smtp,
          siteURL: siteURL,
          secureCookies: secureCookies,
          privateDirectories: privateDirectories
        ),
        persistDriver: persist,
        postgresClient: client
      )
    } catch {
      throw ShapeTreeSetupError.authSetup("\(error)")
    }
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

private struct AuthServicesBundle: Sendable {
  let services: AuthServices
  let persistDriver: PostgresPersistDriver
  let postgresClient: PostgresClient
}
