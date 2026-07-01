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
  private let postsByID: [String: Post]
  public let posts: [Post]

  public init(
    contentDirectory: URL,
    indexSlug: String,
    loginSlug: String,
    privateDirectories: Set<String> = []
  ) throws {
    guard FileManager.default.fileExists(atPath: contentDirectory.path) else {
      throw ContentStoreError.directoryNotFound(contentDirectory)
    }

    let root = contentDirectory.standardizedFileURL
    let loaded = try Self.loadPosts(
      from: root,
      indexSlug: indexSlug,
      loginSlug: loginSlug,
      privateDirectories: privateDirectories
    )
    self.posts = loaded.sorted { $0.date > $1.date }
    self.postsByID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
  }

  public func post(slug: String, in section: ContentSection) -> Post? {
    postsByID["\(section.rawValue)/\(slug)"]
  }

  public func posts(
    in section: ContentSection,
    includingPrivate: Bool
  ) -> [Post] {
    posts.filter { post in
      guard post.section == section else { return false }
      guard !post.isIndex && !post.isLogin else { return false }
      if post.isPrivate { return includingPrivate }
      return true
    }
  }

  public var hasArticles: Bool {
    !posts(in: .articles, includingPrivate: false).isEmpty
  }

  public var hasFavorites: Bool {
    !posts(in: .favorites, includingPrivate: false).isEmpty
  }

  private static func loadPosts(
    from root: URL,
    indexSlug: String,
    loginSlug: String,
    privateDirectories: Set<String>
  ) throws -> [Post] {
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
      let relativePath = fileURL.path(from: root)
      let directory = (relativePath as NSString).deletingLastPathComponent
      guard let section = ContentSection(rawValue: directory) else { continue }

      let source: String
      do {
        source = try String(contentsOf: fileURL, encoding: .utf8)
      } catch {
        throw ContentStoreError.unreadableFile(fileURL, underlying: error)
      }

      let (frontMatter, body) = FrontMatterParser.split(source)
      let slug = fileURL.deletingPathExtension().lastPathComponent
      let title = frontMatter.title ?? humanizedName(slug)
      let isPrivate = privateDirectories.contains(directory)
      let isLogin = slug.lowercased() == loginSlug.lowercased()
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
          relativePath: relativePath,
          section: section,
          isIndex: slug.lowercased() == indexSlug.lowercased(),
          isLogin: isLogin,
          isPrivate: isPrivate
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

  private static func dateFromFilename(_ slug: String) -> Date? {
    let prefix = slug.prefix(while: { $0.isNumber || $0 == "-" })
    guard prefix.count == 10 else { return nil }
    return DateFormatting.date(fromFilename: String(prefix))
  }
}

extension URL {
  fileprivate func path(from root: URL) -> String {
    let rootComponents = root.standardizedFileURL.pathComponents
    let selfComponents = standardizedFileURL.pathComponents
    guard selfComponents.count > rootComponents.count else { return lastPathComponent }
    guard
      zip(rootComponents, selfComponents).allSatisfy({
        $0.0.caseInsensitiveCompare($0.1) == .orderedSame
      })
    else {
      return lastPathComponent
    }
    return selfComponents.dropFirst(rootComponents.count).joined(separator: "/")
  }
}
