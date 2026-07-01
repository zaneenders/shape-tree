import Foundation
import Testing
@testable import ShapeTreeContent

@Test func contentStoreLoadsArticlesAndFavoritesFromDirectory() throws {
  let contentPath = expandHomePath("~/content")
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

  let favorites = store.posts(in: .favorites, includingPrivate: false)
  #expect(!favorites.isEmpty)
  #expect(favorites.contains { $0.slug == "Qoutes" })

  let article = try #require(store.post(slug: "building-a-reverse-proxy-server-using-hummingbird", in: .articles))
  #expect(article.title.localizedCaseInsensitiveContains("reverse proxy"))
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
