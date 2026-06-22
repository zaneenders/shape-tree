import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite struct PrivateWasmPostTests {
  @Test func unauthenticatedPrivateContentRoutesReturnNotFound() async throws {
    let store = try TestContentFixtures.makeStore(
      nodes: [
        ("Home", "Home"),
        ("Private/secret", "Secret Post"),
      ],
      privateDirectories: ["Private"]
    )

    let router = Router(context: AppRequestContext.self)
    ContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/content/Private/secret.wasm", method: .get) { response in
        #expect(response.status == .notFound)
      }

      let documentHeaders: HTTPFields = [HTTPField.Name("Sec-Fetch-Dest")!: "document"]
      try await client.execute(
        uri: "/content/Private/secret",
        method: .get,
        headers: documentHeaders
      ) { response in
        #expect(response.status == .ok)
        let body = String(buffer: response.body)
        #expect(body.contains("data-index-path=\"Home\""))
      }
    }
  }
}
