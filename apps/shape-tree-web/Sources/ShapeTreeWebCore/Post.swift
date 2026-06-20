import Foundation

public struct Post: Sendable, Equatable, Identifiable {
  public var slug: String
  public var title: String
  public var date: Date
  public var tags: [String]
  public var excerpt: String?
  public var bodyMarkdown: String
  public var bodyHTML: String
  public var relativePath: String
  public var isIndex: Bool
  public var isPrivate: Bool

  public var id: String { slug }

  public init(
    slug: String,
    title: String,
    date: Date,
    tags: [String] = [],
    excerpt: String? = nil,
    bodyMarkdown: String,
    bodyHTML: String,
    relativePath: String,
    isIndex: Bool = false,
    isPrivate: Bool = false
  ) {
    self.slug = slug
    self.title = title
    self.date = date
    self.tags = tags
    self.excerpt = excerpt
    self.bodyMarkdown = bodyMarkdown
    self.bodyHTML = bodyHTML
    self.relativePath = relativePath
    self.isIndex = isIndex
    self.isPrivate = isPrivate
  }

  public var path: String {
    isIndex ? "/" : "/posts/\(slug)"
  }

  public var contentURL: String {
    isIndex
      ? "/htmx/content/index"
      : "/htmx/content/posts/\(slug)"
  }

  /// Parent directory within the content root, if any (e.g. `notes` for `notes/post.md`).
  public var contentDirectory: String? {
    let parent = (relativePath as NSString).deletingLastPathComponent
    return parent.isEmpty ? nil : parent
  }
}
