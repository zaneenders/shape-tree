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

  public var id: String { slug }

  public init(
    slug: String,
    title: String,
    date: Date,
    tags: [String] = [],
    excerpt: String? = nil,
    bodyMarkdown: String,
    bodyHTML: String,
    relativePath: String
  ) {
    self.slug = slug
    self.title = title
    self.date = date
    self.tags = tags
    self.excerpt = excerpt
    self.bodyMarkdown = bodyMarkdown
    self.bodyHTML = bodyHTML
    self.relativePath = relativePath
  }

  public var path: String {
    slug == ContentStore.indexSlug ? "/" : "/posts/\(slug)"
  }

  public var contentURL: String {
    slug == ContentStore.indexSlug
      ? "/htmx/content/index"
      : "/htmx/content/posts/\(slug)"
  }
}
