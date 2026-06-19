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
    #expect(store.publishedPosts.allSatisfy { $0.slug != ContentStore.indexSlug })
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
