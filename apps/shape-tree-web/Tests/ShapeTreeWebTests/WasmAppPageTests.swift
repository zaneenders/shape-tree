import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite struct WasmAppPageTests {
  @Test func contentPageShellIsUnified() async throws {
    let store = try TestContentFixtures.makeStore(nodes: [
      ("Home", "Home"),
      ("Apps/Canvas", "Canvas"),
    ])

    let router = Router(context: AppRequestContext.self)
    ContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    let documentHeaders: HTTPFields = [HTTPField.Name("Sec-Fetch-Dest")!: "document"]
    try await app.test(TestingSetup.router) { client in
      try await client.execute(
        uri: "/content/Apps/Canvas",
        method: .get,
        headers: documentHeaders
      ) { response in
        #expect(response.status == .ok)
        let body = String(buffer: response.body)
        #expect(body.contains("data-index-path=\"Home\""))
        #expect(!body.contains("data-initial-wasm"))
      }

      try await client.execute(uri: "/content/Apps/Canvas.wasm", method: .get) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/wasm")
        #expect(response.body.readableBytes > 0)
      }
    }
  }
}
