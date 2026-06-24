import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite struct NavContentRoutesTests {
  @Test func getNavContentReturnsJSON() async throws {
    let store = try TestContentFixtures.makeStore(nodes: [
      ("Home", "ShapeTree Web"),
      ("style-guide", "Style Guide"),
    ])

    let router = Router(context: AppRequestContext.self)
    NavContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/api/get-nav-content", method: .get) { response in
        #expect(response.status == .ok)
        let body = String(buffer: response.body)
        let payload = try JSONDecoder().decode(NavContentResponse.self, from: Data(body.utf8))
        #expect(payload.siteTitle == "ShapeTree Web")
        #expect(payload.home.path == "Home")
        #expect(payload.groups.flatMap(\.items).contains { $0.path == "style-guide" })
      }
    }
  }
}
