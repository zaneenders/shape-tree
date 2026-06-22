import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite struct LoginContentRoutesTests {
  @Test func getLoginContentReturnsJSON() async throws {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("login-content-api-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: contentDir) }

    try """
    ---
    title: Sign in
    ---
    {{login}}
    """.write(to: contentDir.appendingPathComponent("login.md"), atomically: true, encoding: .utf8)

    try """
    ---
    title: ShapeTree Web
    ---
    # Home
    """.write(to: contentDir.appendingPathComponent("Home.md"), atomically: true, encoding: .utf8)

    let store = try ContentStore(
      contentDirectory: contentDir,
      indexSlug: "Home",
      loginSlug: "login"
    )

    let router = Router(context: AppRequestContext.self)
    LoginContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(
        uri: "/api/get-login-content?next=%2Fwasm%2Fposts%2Fsecret",
        method: .get
      ) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/json; charset=utf-8")
        #expect(response.headers[.cacheControl] == "private, no-store")

        let body = String(buffer: response.body)
        let payload = try JSONDecoder().decode(LoginContentResponse.self, from: Data(body.utf8))
        #expect(payload.title == "Sign in")
        #expect(payload.next == "/wasm/posts/secret")
        #expect(!payload.bodyHTML.contains("{{login}}"))
      }
    }
  }

  @Test func rejectsUnsafeNextQuery() async throws {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("login-content-unsafe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: contentDir) }

    try "---\ntitle: Home\n---\n".write(
      to: contentDir.appendingPathComponent("Home.md"),
      atomically: true,
      encoding: .utf8
    )

    let store = try ContentStore(
      contentDirectory: contentDir,
      indexSlug: "Home",
      loginSlug: "login"
    )

    let router = Router(context: AppRequestContext.self)
    LoginContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(
        uri: "/api/get-login-content?next=//evil.com",
        method: .get
      ) { response in
        let body = String(buffer: response.body)
        let payload = try JSONDecoder().decode(LoginContentResponse.self, from: Data(body.utf8))
        #expect(payload.next == nil)
      }
    }
  }
}
