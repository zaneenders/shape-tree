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

public struct PostGroup: Sendable, Equatable {
  public var directory: String?
  public var posts: [Post]

  public var label: String {
    guard let directory else { return "Root" }
    return
      directory
      .split(separator: "/")
      .map { ContentStore.humanizedName(String($0)) }
      .joined(separator: " / ")
  }
}

public struct ContentStore: Sendable {
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
    indexPost?.title ?? "ShapeTree Web"
  }

  public func post(slug: String) -> Post? {
    postsBySlug[slug]
  }

  public var indexPost: Post? {
    posts.first { $0.isIndex }
  }

  public var publishedPosts: [Post] {
    posts.filter { !$0.isIndex }
  }

  public var publishedPostGroups: [PostGroup] {
    var grouped: [String?: [Post]] = [:]
    for post in publishedPosts {
      grouped[post.contentDirectory, default: []].append(post)
    }

    let sortedKeys = grouped.keys.sorted { lhs, rhs in
      switch (lhs, rhs) {
      case (nil, nil):
        return false
      case (nil, _):
        return true
      case (_, nil):
        return false
      case (let lhs?, let rhs?):
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
      }
    }

    return sortedKeys.map { directory in
      PostGroup(
        directory: directory,
        posts: (grouped[directory] ?? []).sorted { $0.date > $1.date }
      )
    }
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
      let title = frontMatter.title ?? humanizedName(slug)
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
          bodyHTML: MarkdownRenderer.html(from: body, strippingTitle: title),
          relativePath: relativePath,
          isIndex: isIndexSlug(slug)
        )
      )
    }
    return posts
  }

  static func humanizedName(_ value: String) -> String {
    value
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  private static let indexSlugs: Set<String> = ["home"]

  private static func isIndexSlug(_ slug: String) -> Bool {
    indexSlugs.contains(slug.lowercased())
  }

  private static func dateFromFilename(_ slug: String) -> Date? {
    let prefix = slug.prefix(while: { $0.isNumber || $0 == "-" })
    guard prefix.count == 10 else { return nil }
    return DateFormatting.date(fromFilename: String(prefix))
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
