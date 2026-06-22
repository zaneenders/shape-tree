import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import ShapeTreeWebAssets
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite
struct WasmAppPageTests {
  @Test
  func appPageShellBootsWasmClient() async throws {
    guard PostWasmAsset.isAvailable, PostWasmAsset.availableSlugs.contains("Canvas") else {
      Issue.record("Canvas.wasm not embedded — run ./Scripts/build-client.sh first")
      return
    }

    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("wasm-app-page-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: contentDir) }

    try """
    ---
    title: Home
    ---
    # Home
    """.write(to: contentDir.appendingPathComponent("Home.md"), atomically: true, encoding: .utf8)

    let store = try ContentStore(
      contentDirectory: contentDir,
      indexSlug: "Home",
      loginSlug: "login"
    )

    let router = Router(context: AppRequestContext.self)
    WasmPostRoutes.register(on: router, store: store, homeSlug: "Home")

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/wasm/posts/Canvas", method: .get) { response in
        #expect(response.status == .ok)
        let body = String(buffer: response.body)
        #expect(body.contains("data-initial-wasm-slug=\"Canvas\""))
        #expect(body.contains("data-initial-wasm-title=\"Canvas\""))
      }

      try await client.execute(uri: "/wasm/wasms/Canvas", method: .get) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/wasm")
        #expect(response.body.readableBytes > 0)
      }
    }
  }
}
