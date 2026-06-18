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

    #expect(store.posts.count >= 2)
    #expect(store.indexPost?.title == "ShapeTree Web")
    #expect(store.post(slug: "2025-06-17-hello-markdown")?.title == "Hello, Markdown")
    #expect(store.publishedPosts.allSatisfy { $0.slug != ContentStore.indexSlug })
  }
}

@Suite struct MarkdownRendererTests {
  @Test func rendersHeadings() {
    let html = MarkdownRenderer.html(from: "# Title")
    #expect(html.contains("<h1>"))
    #expect(html.contains("Title"))
  }
}
