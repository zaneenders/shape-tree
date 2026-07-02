import Foundation
import Testing

@testable import ShapeTreeContent

private func exampleContentPath() -> String {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("example-content")
    .path
}

@Test func contentStoreLoadsArticlesAndFavoritesFromDirectory() throws {
  let contentPath = exampleContentPath()
  #expect(FileManager.default.fileExists(atPath: contentPath))

  let store = try ContentStore(
    contentDirectory: URL(fileURLWithPath: contentPath),
    indexSlug: "Home",
    loginSlug: "login"
  )

  #expect(!store.posts.isEmpty, "Loaded \(store.posts.count) posts from \(contentPath)")

  let articles = store.posts(in: .articles, includingPrivate: false)
  #expect(!articles.isEmpty)
  #expect(articles.allSatisfy { $0.section == .articles })
  #expect(!articles.contains { $0.slug == "Home" })
  #expect(!articles.contains { $0.slug == "login" })

  let favorites = store.posts(in: .favorites, includingPrivate: false)
  #expect(!favorites.isEmpty)
  #expect(favorites.contains { $0.slug == "shape-tree-links" })

  let article = try #require(store.post(slug: "welcome-to-shape-tree", in: .articles))
  #expect(article.title == "Welcome to ShapeTree")
  #expect(!article.bodyMarkdown.isEmpty)
}

@Test func frontMatterParsesShortDate() {
  let source = """
    -----

    date: 25-04-26

    -----

    # Title

    Body
    """

  let (frontMatter, body) = FrontMatterParser.split(source)
  #expect(frontMatter.date != nil)
  #expect(body.contains("# Title"))
}
