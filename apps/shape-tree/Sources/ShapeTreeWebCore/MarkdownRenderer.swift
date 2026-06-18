import Markdown

public enum MarkdownRenderer: Sendable {
  public static func html(from markdown: String) -> String {
    HTMLFormatter.format(markdown)
  }
}
