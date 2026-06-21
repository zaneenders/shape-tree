import Foundation
import Testing

@testable import ShapeTreeWebCore

@Suite struct FrontMatterParserTests {
  @Test func splitsFrontMatterFromBody() {
    let source = """
      ---
      title: Hello
      date: 2025-06-17
      tags:
        - swift
        - web
      excerpt: Short summary
      ---

      # Body
      """

    let (frontMatter, body) = FrontMatterParser.split(source)

    #expect(frontMatter.title == "Hello")
    #expect(frontMatter.tags == ["swift", "web"])
    #expect(frontMatter.excerpt == "Short summary")
    #expect(frontMatter.date != nil)
    #expect(body.hasPrefix("# Body"))
  }

  @Test func returnsBodyWhenFrontMatterMissing() {
    let source = "# Just markdown"
    let (frontMatter, body) = FrontMatterParser.split(source)
    #expect(frontMatter == FrontMatter())
    #expect(body == source)
  }

  @Test func parsesIndexStyleFrontMatter() {
    let source = """
      ---
      title: ShapeTree Web
      ---

      Intro paragraph.
      """

    let (frontMatter, body) = FrontMatterParser.split(source)

    #expect(frontMatter.title == "ShapeTree Web")
    #expect(body.hasPrefix("Intro paragraph."))
  }

  @Test func parsesFrontMatterWithCRLFLineEndings() {
    let source =
      "---\r\n"
      + "title: Hello\r\n"
      + "date: 2025-06-17\r\n"
      + "tags:\r\n"
      + "  - swift\r\n"
      + "  - web\r\n"
      + "excerpt: Short summary\r\n"
      + "---\r\n"
      + "\r\n"
      + "# Body\r\n"

    let (frontMatter, body) = FrontMatterParser.split(source)

    #expect(frontMatter.title == "Hello")
    #expect(frontMatter.tags == ["swift", "web"])
    #expect(frontMatter.excerpt == "Short summary")
    #expect(frontMatter.date != nil)
    #expect(body.hasPrefix("# Body"))
  }
}

@Suite struct ContentStoreTests {
  @Test func loadsMarkdownFilesFromDirectory() throws {
    let contentDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Examples/content", isDirectory: true)

    let store = try ContentStore(contentDirectory: contentDirectory)

    #expect(store.posts.count >= 6)
    #expect(store.indexPost?.title == "ShapeTree Web")
    #expect(store.post(slug: "style-guide")?.title == "Style Guide")
    #expect(store.loginPost?.title == "Sign in")
    #expect(store.loginPost?.isLogin == true)
    #expect(store.publishedPosts.allSatisfy { !$0.isIndex && !$0.isLogin })
  }

  @Test func groupsPublishedPostsByDirectory() throws {
    let contentDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Examples/content", isDirectory: true)

    let store = try ContentStore(contentDirectory: contentDirectory)
    let groups = store.publishedPostGroups

    #expect(groups.contains { $0.directory == nil })
    #expect(groups.contains { $0.directory == "notes" })
    #expect(groups.contains { $0.directory == "guides" })
    #expect(groups.contains { $0.directory == "fragments" })
    #expect(groups.first?.directory == nil)
    #expect(groups.first(where: { $0.directory == "notes" })?.label == "Notes")
    #expect(groups.first(where: { $0.directory == "notes" })?.posts.count == 2)
  }

  @Test func detectsLoginPost() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )
    let loginPost = "---\ntitle: Sign in\n---\nEnter your email."
    let regularPost = "---\ntitle: Hello\n---\nBody."
    try loginPost.write(
      to: temporaryDirectory.appendingPathComponent("login.md"),
      atomically: true,
      encoding: .utf8
    )
    try regularPost.write(
      to: temporaryDirectory.appendingPathComponent("hello.md"),
      atomically: true,
      encoding: .utf8
    )

    let store = try ContentStore(contentDirectory: temporaryDirectory)

    #expect(store.loginPost?.slug == "login")
    #expect(store.loginPost?.isLogin == true)
    #expect(store.post(slug: "hello")?.isLogin == false)
    #expect(store.publishedPosts.contains { $0.slug == "login" } == false)
    #expect(store.publishedPosts.contains { $0.slug == "hello" })

    try FileManager.default.removeItem(at: temporaryDirectory)
  }

  @Test func honorsCustomLoginSlug() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )
    let loginPost = "---\ntitle: Members\n---\nMembers only."
    try loginPost.write(
      to: temporaryDirectory.appendingPathComponent("members.md"),
      atomically: true,
      encoding: .utf8
    )

    let store = try ContentStore(contentDirectory: temporaryDirectory, loginSlug: "members")

    #expect(store.loginPost?.slug == "members")
    #expect(store.loginPost?.isLogin == true)
    #expect(store.publishedPosts.isEmpty)

    try FileManager.default.removeItem(at: temporaryDirectory)
  }

  @Test func hidesPrivateDirectories() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory.appendingPathComponent("Private", isDirectory: true),
      withIntermediateDirectories: true
    )
    let publicPost = "---\ntitle: Public Post\n---\nHello."
    let privatePost = "---\ntitle: Secret Post\n---\nSecret."
    try publicPost.write(
      to: temporaryDirectory.appendingPathComponent("Public.md"),
      atomically: true,
      encoding: .utf8
    )
    try privatePost.write(
      to: temporaryDirectory.appendingPathComponent("Private/Secret.md"),
      atomically: true,
      encoding: .utf8
    )

    let store = try ContentStore(
      contentDirectory: temporaryDirectory,
      privateDirectories: ["Private"]
    )

    #expect(store.posts.count == 2)
    #expect(store.post(slug: "Public")?.isPrivate == false)
    #expect(store.post(slug: "Secret")?.isPrivate == true)
    #expect(store.publishedPosts.contains { $0.slug == "Public" })
    #expect(!store.publishedPosts.contains { $0.slug == "Secret" })
    #expect(store.publishedPostGroups.allSatisfy { $0.directory != "Private" })
    #expect(store.postGroups(includingPrivate: true).contains { $0.directory == "Private" })
    #expect(
      store.postGroups(includingPrivate: true).flatMap(\.posts).contains { $0.slug == "Secret" }
    )

    try FileManager.default.removeItem(at: temporaryDirectory)
  }
}

@Suite struct MarkdownRendererTests {
  @Test func rendersHeadings() {
    let html = MarkdownRenderer.html(from: "# Title")
    #expect(html.contains("<h1>"))
    #expect(html.contains("Title"))
  }

  @Test func stripsLeadingTitleHeading() {
    let markdown = "# Hello, Markdown\n\nBody text."
    let html = MarkdownRenderer.html(from: markdown, strippingTitle: "Hello, Markdown")
    #expect(!html.contains("<h1>"))
    #expect(html.contains("Body text."))
  }

  @Test func keepsLeadingHeadingWhenTitleDiffers() {
    let markdown = "# Something Else\n\nBody text."
    let html = MarkdownRenderer.html(from: markdown, strippingTitle: "Hello, Markdown")
    #expect(html.contains("<h1>"))
    #expect(html.contains("Something Else"))
  }

  @Test func keepsLeadingHeadingWhenNotLevelOne() {
    let markdown = "## Hello, Markdown\n\nBody text."
    let html = MarkdownRenderer.html(from: markdown, strippingTitle: "Hello, Markdown")
    #expect(html.contains("<h2>"))
  }
}
