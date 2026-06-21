import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdTesting
import HTTPTypes
import ShapeTreeWebAssets
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite
/// Wasm route tests require embedded `WasmPosts` from `./Scripts/build-client.sh`.
/// When artifacts are missing, `unauthenticatedPrivateWasmRoutesReturnNotFound` records
/// an issue instead of failing opaquely.
struct PrivateWasmPostTests {
  @Test
  func unauthenticatedPrivateWasmRoutesReturnNotFound() async throws {
    guard PostWasmAsset.isAvailable else {
      Issue.record("WasmPosts not embedded — run ./Scripts/build-client.sh first")
      return
    }

    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("private-wasm-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: contentDir) }

    try """
    ---
    title: Home
    ---
    # Home
    """.write(to: contentDir.appendingPathComponent("Home.md"), atomically: true, encoding: .utf8)

    let privateDir = contentDir.appendingPathComponent("Private", isDirectory: true)
    try FileManager.default.createDirectory(at: privateDir, withIntermediateDirectories: true)
    try """
    ---
    title: Secret Post
    ---
    Hidden.
    """.write(to: privateDir.appendingPathComponent("secret.md"), atomically: true, encoding: .utf8)

    let store = try ContentStore(
      contentDirectory: contentDir,
      indexSlug: "Home",
      loginSlug: "login",
      privateDirectories: ["Private"]
    )

    let router = Router(context: AppRequestContext.self)
    WasmPostRoutes.register(on: router, store: store, homeSlug: "Home")

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/wasm/posts/secret", method: .get) { response in
        #expect(response.status == .notFound)
        let body = String(buffer: response.body)
        #expect(body.contains("data-boot-not-found=\"true\""))
        #expect(body.contains("id=\"styled-navigation\""))
        #expect(body.contains("/assets/client/bootstrap.js"))
        #expect(body.contains("<main id=\"main\"></main>"))
      }

      try await client.execute(uri: "/wasm/wasms/secret", method: .get) { response in
        #expect(response.status == .notFound)
      }
    }
  }

  @Test
  func notFoundArticleContainsExpectedCopy() throws {
    let html = WebPages.notFoundArticle().render()
    #expect(html.contains("<h1>404</h1>"))
    #expect(html.contains("Page not found."))
  }
}
