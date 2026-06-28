import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdCompression
import Logging
import ShapeTreeConfig
import ShapeTreeMarkdown
import ShapeTreeWebBuilder

enum StartupError: Error {
  case missingBootstrap(path: String)
}

do {
  let packageRoot = PackageConfig.packageRoot(fromFilePath: #filePath)

  let settings = try await AppSettings.load(packageRoot: packageRoot)

  if !settings.skipShapeTreeWebBuild {
    try await ShapeTreeWebBuilder.run(packageRoot: packageRoot)
  }

  let js = "\(settings.staticRoot)/app.js"
  let css = "\(settings.staticRoot)/app.css"
  let appjs = try String(contentsOfFile: js, encoding: .utf8)
  let styles = try String(contentsOfFile: css, encoding: .utf8)

  guard !appjs.isEmpty else {
    throw StartupError.missingBootstrap(path: appjs)
  }
  guard !styles.isEmpty else {
    throw StartupError.missingBootstrap(path: styles)
  }

  let router = Router()

  router.addMiddleware {
    LogRequestsMiddleware(.info)
  }

  router.addMiddleware {
    ResponseCompressionMiddleware(minimumResponseSizeToCompress: 512)
  }

  router.get { _, _ in
    EditedResponse(
      headers: [.contentType: "text/html; charset=utf-8"],
      response: WebAssets.indexHTML(styles: styles, bootstrapScript: appjs)
    )
  }

  router.get("api/message") { _, _ in
    Message(message: "Hello from Hummingbird!", server: "Swift 6.3")
  }

  let articlePath = "\(settings.staticRoot)/article.md"
  router.get("api/article") { _, _ in
    try loadArticleDocument(from: URL(fileURLWithPath: articlePath))
  }

  router.addMiddleware {
    FileMiddleware(settings.staticRoot)
  }

  let app = Application(
    router: router,
    configuration: .init(address: .hostname(settings.hostname, port: settings.port))
  )

  try await app.runService()
} catch {
  let logger = Logger(label: "ShapeTreeWeb")
  logger.error("Startup failed", metadata: ["error": "\(error)"])
  if let data = "error: \(error)\n".data(using: .utf8) {
    try? FileHandle.standardError.write(contentsOf: data)
  }
  exit(1)
}

private struct Message: ResponseEncodable {
  let message: String
  let server: String
}

extension ArticleDocument: ResponseEncodable {}
