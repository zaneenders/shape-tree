import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

@Suite struct PostContentRoutesTests {
  @Test func getPostContentReturnsJSON() async throws {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("post-content-api-\(UUID().uuidString)", isDirectory: true)
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
    title: Getting Started
    ---

    Welcome aboard.
    """.write(
      to: contentDir.appendingPathComponent("getting-started.md"),
      atomically: true,
      encoding: .utf8
    )

    let store = try ContentStore(
      contentDirectory: contentDir,
      indexSlug: "Home",
      loginSlug: "login"
    )

    let router = Router(context: AppRequestContext.self)
    PostContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/api/get-post-content/getting-started", method: .get) { response in
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "application/json; charset=utf-8")
        #expect(response.headers[.cacheControl] == "private, no-store")

        let body = String(buffer: response.body)
        let payload = try JSONDecoder().decode(PostContentResponse.self, from: Data(body.utf8))
        #expect(payload.slug == "getting-started")
        #expect(payload.title == "Getting Started")
        #expect(payload.articleHTML.contains("<article>"))
        #expect(payload.articleHTML.contains("Welcome aboard."))
      }
    }
  }

  @Test func privatePostReturnsNotFoundWhenUnauthenticated() async throws {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("post-content-private-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: contentDir) }

    try "---\ntitle: Home\n---\n".write(
      to: contentDir.appendingPathComponent("Home.md"),
      atomically: true,
      encoding: .utf8
    )

    let privateDir = contentDir.appendingPathComponent("Private", isDirectory: true)
    try FileManager.default.createDirectory(at: privateDir, withIntermediateDirectories: true)
    try """
    ---
    title: Secret
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
    PostContentRoutes.register(on: router, store: store)

    let app = Application(router: router)
    try await app.test(TestingSetup.router) { client in
      try await client.execute(uri: "/api/get-post-content/secret", method: .get) { response in
        #expect(response.status == .notFound)
      }
    }
  }
}
