import Foundation
import Markdown

public enum MarkdownRenderer: Sendable {
  public static func html(from markdown: String) -> String {
    HTMLFormatter.format(markdown)
  }

  /// Renders markdown to HTML, dropping a leading level-1 heading when it just
  /// repeats the post title (the title is rendered separately by the layout).
  public static func html(from markdown: String, strippingTitle title: String) -> String {
    let document = Document(parsing: markdown)
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

    guard
      !trimmedTitle.isEmpty,
      let heading = document.child(at: 0) as? Heading,
      heading.level == 1,
      heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        .caseInsensitiveCompare(trimmedTitle) == .orderedSame
    else {
      return HTMLFormatter.format(document)
    }

    let remaining = document.children.dropFirst().compactMap { $0 as? BlockMarkup }
    return HTMLFormatter.format(Document(remaining))
  }
}
