import Foundation

public enum ContentSection: String, Sendable, CaseIterable, Codable {
  case articles = "Articles"
  case favorites = "Favorites"
}

public struct Post: Sendable, Equatable, Identifiable {
  public var slug: String
  public var title: String
  public var date: Date
  public var tags: [String]
  public var excerpt: String?
  public var bodyMarkdown: String
  public var relativePath: String
  public var section: ContentSection
  public var isIndex: Bool
  public var isLogin: Bool
  public var isPrivate: Bool

  public var id: String { "\(section.rawValue)/\(slug)" }

  public init(
    slug: String,
    title: String,
    date: Date,
    tags: [String] = [],
    excerpt: String? = nil,
    bodyMarkdown: String,
    relativePath: String,
    section: ContentSection,
    isIndex: Bool = false,
    isLogin: Bool = false,
    isPrivate: Bool = false
  ) {
    self.slug = slug
    self.title = title
    self.date = date
    self.tags = tags
    self.excerpt = excerpt
    self.bodyMarkdown = bodyMarkdown
    self.relativePath = relativePath
    self.section = section
    self.isIndex = isIndex
    self.isLogin = isLogin
    self.isPrivate = isPrivate
  }

  public var contentDirectory: String {
    section.rawValue
  }
}
