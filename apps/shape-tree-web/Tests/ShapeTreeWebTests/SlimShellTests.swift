import Foundation
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb

@Suite struct SlimShellTests {
  @Test func shellHasEmptyNavAndMain() throws {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("slim-shell-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: contentDir) }

    try "---\ntitle: Home\n---\n# Home\n".write(
      to: contentDir.appendingPathComponent("Home.md"),
      atomically: true,
      encoding: .utf8
    )

    let store = try ContentStore(
      contentDirectory: contentDir,
      indexSlug: "Home",
      loginSlug: "login"
    )

    let html = WebPages.shell(store: store, homeSlug: "Home").render()

    #expect(html.contains("id=\"styled-navigation\""))
    #expect(html.contains("<main id=\"main\"></main>"))
    #expect(html.contains("/assets/client/bootstrap.js"))
    #expect(!html.contains("htmx.org"))
    #expect(!html.contains("hx-get"))
    #expect(html.contains("data-home-slug=\"Home\""))
  }

  @Test func notFoundShellBootsClientSide404() throws {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("slim-shell-404-\(UUID().uuidString)", isDirectory: true)
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

    let html = WebPages.shell(
      store: store,
      homeSlug: "Home",
      documentTitle: "Not Found · \(store.siteTitle)",
      bootNotFound: true
    ).render()

    #expect(html.contains("data-boot-not-found=\"true\""))
    #expect(html.contains("<main id=\"main\"></main>"))
    #expect(!html.contains("<h1>404</h1>"))
  }
}
