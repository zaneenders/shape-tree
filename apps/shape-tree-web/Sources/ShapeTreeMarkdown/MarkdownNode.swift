import Foundation
import Markdown

public struct MarkdownNode: Codable, Sendable {
  public let kind: String
  public var text: String?
  public var level: Int?
  public var language: String?
  public var destination: String?
  public var source: String?
  public var children: [MarkdownNode]?

  public init(
    kind: String,
    text: String? = nil,
    level: Int? = nil,
    language: String? = nil,
    destination: String? = nil,
    source: String? = nil,
    children: [MarkdownNode]? = nil
  ) {
    self.kind = kind
    self.text = text
    self.level = level
    self.language = language
    self.destination = destination
    self.source = source
    self.children = children
  }
}

public struct ArticleDocument: Codable, Sendable {
  public let root: MarkdownNode

  public init(root: MarkdownNode) {
    self.root = root
  }
}

public enum ArticleParseError: Error {
  case readFailed
}

public func parseArticleDocument(from markdown: String) -> ArticleDocument {
  let document = Document(parsing: markdown)
  var encoder = MarkdownJSONEncoder()
  return ArticleDocument(root: encoder.visit(document))
}

public func loadArticleDocument(from url: URL) throws(ArticleParseError) -> ArticleDocument {
  let markdown: String
  do {
    markdown = try String(contentsOf: url, encoding: .utf8)
  } catch {
    throw ArticleParseError.readFailed
  }
  return parseArticleDocument(from: markdown)
}
