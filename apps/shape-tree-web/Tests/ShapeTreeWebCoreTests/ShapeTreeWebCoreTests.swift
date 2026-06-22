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
