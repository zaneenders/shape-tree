import Foundation
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb

@Suite struct SlimShellTests {
  @Test func shellHasEmptyNavAndMain() throws {
    let store = try TestContentFixtures.makeStore(nodes: [("Home", "ShapeTree Web")])

    let html = WebPages.shell(store: store).render()

    #expect(html.contains("id=\"styled-navigation\""))
    #expect(html.contains("<main id=\"main\"></main>"))
    #expect(html.contains("/assets/client/bootstrap.js"))
    #expect(html.contains("data-index-path=\"Home\""))
    #expect(!html.contains("data-boot-login"))
  }

  @Test func notFoundShellUsesUnifiedShape() throws {
    let store = try TestContentFixtures.makeStore(nodes: [("Home", "Home")])

    let html = WebPages.shell(
      store: store,
      documentTitle: "Not Found · \(store.siteTitle)"
    ).render()

    #expect(html.contains("data-index-path=\"Home\""))
    #expect(html.contains("<main id=\"main\"></main>"))
    #expect(!html.contains("data-boot-not-found"))
  }
}
