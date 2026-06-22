import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import NIOCore
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite struct NotFoundRoutesTests {
  private func testStore() throws -> ContentStore {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("not-found-routes-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    try """
    ---
    title: Home
    ---
    # Home
    """.write(to: contentDir.appendingPathComponent("Home.md"), atomically: true, encoding: .utf8)

    return try ContentStore(
      contentDirectory: contentDir,
      indexSlug: "Home",
      loginSlug: "login"
    )
  }

  private let documentHeaders: HTTPFields = [HTTPField.Name("Sec-Fetch-Dest")!: "document"]

  @Test func unknownPostShellBootsClientSide404() async throws {
    let store = try testStore()
    let router = Router(context: AppRequestContext.self)
    WasmPostRoutes.register(on: router, store: store, homeSlug: "Home")

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/wasm/posts/wasms", method: .get) { response in
        #expect(response.status == .notFound)
        let body = String(buffer: response.body)
        #expect(body.contains("data-boot-not-found=\"true\""))
        #expect(body.contains("/assets/client/bootstrap.js"))
      }
    }
  }

  @Test func unknownWasmPrefixPathBootsClientSide404() async throws {
    let store = try testStore()
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: NotFoundMiddleware(store: store, homeSlug: "Home"))

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/wasm/wasms", method: .get, headers: documentHeaders) { response in
        #expect(response.status == .notFound)
        let body = String(buffer: response.body)
        #expect(body.contains("data-boot-not-found=\"true\""))
      }
    }
  }

  @Test func partialWasmPathMismatchBootsClientSide404() async throws {
    let store = try testStore()
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: NotFoundMiddleware(store: store, homeSlug: "Home"))
    WasmPostRoutes.register(on: router, store: store, homeSlug: "Home")

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/wasm/post", method: .get, headers: documentHeaders) { response in
        #expect(response.status == .notFound)
        let body = String(buffer: response.body)
        #expect(body.contains("data-boot-not-found=\"true\""))
      }
    }
  }

  @Test func nonHTMLNotFoundReturnsPlain404() async throws {
    let store = try testStore()
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: NotFoundMiddleware(store: store, homeSlug: "Home"))
    WasmPostRoutes.register(on: router, store: store, homeSlug: "Home")

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/wasm/post", method: .get) { response in
        #expect(response.status == .notFound)
        let body = String(buffer: response.body)
        #expect(!body.contains("data-boot-not-found"))
      }
    }
  }

  @Test func headRequestReturnsEmptyBody404() async throws {
    let store = try testStore()
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: NotFoundMiddleware(store: store, homeSlug: "Home"))
    WasmPostRoutes.register(on: router, store: store, homeSlug: "Home")

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/wasm/post", method: .head, headers: documentHeaders) { response in
        #expect(response.status == .notFound)
        #expect(response.headers[.contentType] == "text/html; charset=utf-8")
        #expect(response.body.readableBytes == 0)
      }
    }
  }

  @Test func wasmAssetURLRedirectsDocumentNavigationToPostShell() async throws {
    let store = try testStore()
    let router = Router(context: AppRequestContext.self)
    WasmPostRoutes.register(on: router, store: store, homeSlug: "Home")

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(
        uri: "/wasm/wasms/wasms",
        method: .get,
        headers: documentHeaders
      ) { response in
        #expect(response.status == .seeOther)
        #expect(response.headers[.location] == "/wasm/posts/wasms")
      }
    }
  }
}
