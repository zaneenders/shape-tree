import Markdown

struct MarkdownJSONEncoder: MarkupVisitor {
  typealias Result = MarkdownNode

  mutating func defaultVisit(_ markup: Markup) -> MarkdownNode {
    MarkdownNode(
      kind: String(describing: type(of: markup)),
      children: markup.childCount > 0 ? markup.children.map { visit($0) } : nil
    )
  }

  mutating func visitText(_ text: Text) -> MarkdownNode {
    MarkdownNode(kind: "text", text: text.plainText)
  }

  mutating func visitSoftBreak(_ softBreak: SoftBreak) -> MarkdownNode {
    MarkdownNode(kind: "softBreak")
  }

  mutating func visitLineBreak(_ lineBreak: LineBreak) -> MarkdownNode {
    MarkdownNode(kind: "lineBreak")
  }

  mutating func visitEmphasis(_ emphasis: Emphasis) -> MarkdownNode {
    MarkdownNode(kind: "emphasis", children: emphasis.children.map { visit($0) })
  }

  mutating func visitStrong(_ strong: Strong) -> MarkdownNode {
    MarkdownNode(kind: "strong", children: strong.children.map { visit($0) })
  }

  mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> MarkdownNode {
    MarkdownNode(kind: "strikethrough", children: strikethrough.children.map { visit($0) })
  }

  mutating func visitInlineCode(_ inlineCode: InlineCode) -> MarkdownNode {
    MarkdownNode(kind: "inlineCode", text: inlineCode.code)
  }

  mutating func visitLink(_ link: Link) -> MarkdownNode {
    MarkdownNode(
      kind: "link",
      destination: link.destination,
      children: link.children.map { visit($0) }
    )
  }

  mutating func visitImage(_ image: Image) -> MarkdownNode {
    MarkdownNode(
      kind: "image",
      text: image.plainText,
      source: image.source
    )
  }

  mutating func visitParagraph(_ paragraph: Paragraph) -> MarkdownNode {
    MarkdownNode(kind: "paragraph", children: paragraph.children.map { visit($0) })
  }

  mutating func visitHeading(_ heading: Heading) -> MarkdownNode {
    MarkdownNode(
      kind: "heading",
      level: heading.level,
      children: heading.children.map { visit($0) }
    )
  }

  mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> MarkdownNode {
    MarkdownNode(kind: "blockQuote", children: blockQuote.children.map { visit($0) })
  }

  mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> MarkdownNode {
    MarkdownNode(
      kind: "codeBlock",
      text: codeBlock.code,
      language: codeBlock.language
    )
  }

  mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> MarkdownNode {
    MarkdownNode(kind: "unorderedList", children: unorderedList.children.map { visit($0) })
  }

  mutating func visitOrderedList(_ orderedList: OrderedList) -> MarkdownNode {
    MarkdownNode(kind: "orderedList", children: orderedList.children.map { visit($0) })
  }

  mutating func visitListItem(_ listItem: ListItem) -> MarkdownNode {
    MarkdownNode(kind: "listItem", children: listItem.children.map { visit($0) })
  }

  mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> MarkdownNode {
    MarkdownNode(kind: "thematicBreak")
  }

  mutating func visitHTMLBlock(_ html: HTMLBlock) -> MarkdownNode {
    MarkdownNode(kind: "htmlBlock", text: html.rawHTML)
  }

  mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> MarkdownNode {
    MarkdownNode(kind: "inlineHTML", text: inlineHTML.rawHTML)
  }

  mutating func visitDocument(_ document: Document) -> MarkdownNode {
    MarkdownNode(kind: "document", children: document.children.map { visit($0) })
  }
}
