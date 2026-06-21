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
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("nav-content-api-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: contentDir) }

    try """
    ---
    title: ShapeTree Web
    ---
    # Home
    """.write(to: contentDir.appendingPathComponent("Home.md"), atomically: true, encoding: .utf8)

    try """
    ---
    title: Style Guide
    ---
    Body.
    """.write(to: contentDir.appendingPathComponent("style-guide.md"), atomically: true, encoding: .utf8)

    let store = try ContentStore(
      contentDirectory: contentDir,
      indexSlug: "Home",
      loginSlug: "login"
    )

    let router = Router(context: AppRequestContext.self)
    NavContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/api/get-nav-content", method: .get) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/json; charset=utf-8")
        #expect(response.headers[.cacheControl] == "private, no-store")

        let body = String(buffer: response.body)
        let payload = try JSONDecoder().decode(NavContentResponse.self, from: Data(body.utf8))
        #expect(payload.siteTitle == "ShapeTree Web")
        #expect(payload.viewer.isAuthenticated == false)
        #expect(payload.signIn?.href == "/login")
        #expect(payload.signIn?.spa == true)
        #expect(payload.home.slug == "Home")
        #expect(payload.groups.flatMap(\.items).contains { $0.slug == "style-guide" })
      }
    }
  }
}
