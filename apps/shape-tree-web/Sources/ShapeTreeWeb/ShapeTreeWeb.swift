import Configuration
import Foundation
import HTML
import HTMX
import Hummingbird
import Logging
import NIOCore
import ShapeTreeWebCore

@main
enum ShapeTreeWeb {
  static func main() async throws {
    let log = Logger(label: "shape-tree-web.server")
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
    let contentPath = try config.requiredString(forKey: "CONTENT_PATH")
    let indexSlug = try config.requiredString(forKey: "INDEX_SLUG")
    let otel = try OtelSettings.load(from: config)

    let contentURL = URL(
      fileURLWithPath: contentPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    let store = try ContentStore(contentDirectory: contentURL, indexSlug: indexSlug)
    let initial = store.indexPost ?? store.publishedPosts.first ?? fallbackIndexPost(slug: indexSlug)

    let router = Router()
    if !otel.disabled {
      _ = PrometheusMetrics.registry
      router.addMiddleware {
        TracingMiddleware()
        MetricsMiddleware()
      }
    }

    router.get { _, _ in
      WebPages.shell(store: store, initial: initial).makeHTMLResponse()
    }

    router.get("posts/:slug") { _, context in
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug) else {
        throw HTTPError(.notFound)
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
      guard let post = store.post(slug: slug) else {
        throw HTTPError(.notFound)
      }
      let fragment = WebPages.contentFragment(for: post, store: store)
      return htmlFragmentResponse(fragment)
    }

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

    if !otel.disabled {
      app.addServices(try OtelTracing.bootstrap(settings: otel, logger: app.logger))
    }

    app.logger.info("Serving \(store.posts.count) markdown file(s) from \(contentURL.path)")
    app.logger.info("Listening on http://\(host):\(port)")
    app.logger.info("Admin server listening on http://\(adminHost):\(adminPort)")
    app.logger.info("OpenTelemetry disabled=\(otel.disabled)")

    try await app.runService()
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
