import Foundation

public enum ContentStoreError: Error, CustomStringConvertible, Sendable {
  case directoryNotFound(URL)
  case unreadableFile(URL, underlying: Error)

  public var description: String {
    switch self {
    case .directoryNotFound(let url):
      "Content directory does not exist: \(url.path)"
    case .unreadableFile(let url, let underlying):
      "Could not read \(url.path): \(underlying)"
    }
  }
}

public struct ContentStore: Sendable {
  public static let indexSlug = "index"

  private let root: URL
  private let postsBySlug: [String: Post]
  public let posts: [Post]

  public init(contentDirectory: URL) throws {
    guard FileManager.default.fileExists(atPath: contentDirectory.path) else {
      throw ContentStoreError.directoryNotFound(contentDirectory)
    }

    self.root = contentDirectory.standardizedFileURL
    let loaded = try Self.loadPosts(from: contentDirectory)
    self.posts = loaded.sorted { $0.date > $1.date }
    self.postsBySlug = Dictionary(uniqueKeysWithValues: loaded.map { ($0.slug, $0) })
  }

  public var siteTitle: String {
    postsBySlug[Self.indexSlug]?.title ?? "ShapeTree Web"
  }

  public func post(slug: String) -> Post? {
    postsBySlug[slug]
  }

  public var indexPost: Post? {
    postsBySlug[Self.indexSlug]
  }

  public var publishedPosts: [Post] {
    posts.filter { $0.slug != Self.indexSlug }
  }

  private static func loadPosts(from root: URL) throws -> [Post] {
    let fileManager = FileManager.default
    guard
      let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    var posts: [Post] = []
    for case let fileURL as URL in enumerator {
      guard fileURL.pathExtension.lowercased() == "md" else { continue }
      let relativePath = fileURL.path(
        from: root
      )
      let source: String
      do {
        source = try String(contentsOf: fileURL, encoding: .utf8)
      } catch {
        throw ContentStoreError.unreadableFile(fileURL, underlying: error)
      }

      let (frontMatter, body) = FrontMatterParser.split(source)
      let slug = fileURL.deletingPathExtension().lastPathComponent
      let title = frontMatter.title ?? humanizedSlug(slug)
      let date =
        frontMatter.date
        ?? dateFromFilename(slug)
        ?? (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        ?? .distantPast

      posts.append(
        Post(
          slug: slug,
          title: title,
          date: date,
          tags: frontMatter.tags,
          excerpt: frontMatter.excerpt,
          bodyMarkdown: body,
          bodyHTML: MarkdownRenderer.html(from: body),
          relativePath: relativePath
        )
      )
    }
    return posts
  }

  private static func humanizedSlug(_ slug: String) -> String {
    slug
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  private static func dateFromFilename(_ slug: String) -> Date? {
    let prefix = slug.prefix(while: { $0.isNumber || $0 == "-" })
    guard prefix.count == 10 else { return nil }

    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: String(prefix))
  }
}

extension URL {
  fileprivate func path(from root: URL) -> String {
    let rootPath = root.standardizedFileURL.path + "/"
    let fullPath = standardizedFileURL.path + "/"
    if fullPath.hasPrefix(rootPath) {
      return String(fullPath.dropFirst(rootPath.count).dropLast())
    }
    return lastPathComponent
  }
}
