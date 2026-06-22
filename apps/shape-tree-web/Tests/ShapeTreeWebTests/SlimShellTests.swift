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
    #expect(html.contains("id=\"site-loading\""))
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

  @Test func loginShellBootsClientSideLogin() throws {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("slim-shell-login-\(UUID().uuidString)", isDirectory: true)
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
      documentTitle: "Sign in · \(store.siteTitle)",
      bootLogin: true,
      loginNext: "/wasm/posts/secret"
    ).render()

    #expect(html.contains("data-boot-login=\"true\""))
    #expect(html.contains("data-login-next=\"/wasm/posts/secret\""))
    #expect(html.contains("<main id=\"main\"></main>"))
    #expect(!html.contains("Send link"))
  }

  @Test func verifyShellBootsClientSideConfirm() throws {
    let contentDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("slim-shell-verify-\(UUID().uuidString)", isDirectory: true)
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
      documentTitle: "Confirm sign in · \(store.siteTitle)",
      bootVerify: true,
      verifyToken: "test-token",
      verifyNext: "/wasm/posts/secret"
    ).render()

    #expect(html.contains("data-boot-verify=\"true\""))
    #expect(html.contains("data-verify-token=\"test-token\""))
    #expect(html.contains("data-verify-next=\"/wasm/posts/secret\""))
    #expect(html.contains("/assets/client/bootstrap.js"))
    #expect(html.contains("<main id=\"main\"></main>"))
    #expect(!html.contains("<h1>Confirm sign in</h1>"))
    #expect(!html.contains("auth.css"))
  }
}
