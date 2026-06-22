import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite struct NotFoundRoutesTests {
  private func makeStore() throws -> ContentStore {
    try TestContentFixtures.makeStore(nodes: [("Home", "Home")])
  }

  private let documentHeaders: HTTPFields = [HTTPField.Name("Sec-Fetch-Dest")!: "document"]

  @Test func unknownContentPageReturnsStyledShell404() async throws {
    let store = try makeStore()
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: NotFoundMiddleware(store: store))
    ContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(
        uri: "/content/missing-page",
        method: .get,
        headers: documentHeaders
      ) { response in
        #expect(response.status == .ok)
        let body = String(buffer: response.body)
        #expect(body.contains("data-index-path=\"Home\""))
        #expect(body.contains("/assets/client/bootstrap.js"))
        #expect(!body.contains("data-boot-not-found"))
      }
    }
  }

  @Test func unknownWasmBytesReturn404() async throws {
    let store = try makeStore()
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: NotFoundMiddleware(store: store))
    ContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/content/missing-page.wasm", method: .get) { response in
        #expect(response.status == .notFound)
      }
    }
  }

  @Test func partialContentPathReturnsStyled404() async throws {
    let store = try makeStore()
    let router = Router(context: AppRequestContext.self)
    router.add(middleware: NotFoundMiddleware(store: store))

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/content", method: .get, headers: documentHeaders) { response in
        #expect(response.status == .notFound)
        let body = String(buffer: response.body)
        #expect(body.contains("data-index-path=\"Home\""))
      }
    }
  }
}
