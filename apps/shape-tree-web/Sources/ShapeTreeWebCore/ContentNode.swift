import Foundation

/// A wasm page discovered under the content root (`Articles/new-mac` → `Articles/new-mac.wasm`).
public struct ContentNode: Sendable, Equatable, Identifiable {
  public var path: String
  public var title: String
  public var isPrivate: Bool
  public var isHome: Bool

  public var id: String { path }

  /// Final path component (`new-mac` for `Articles/new-mac`).
  public var slug: String {
    (path as NSString).lastPathComponent
  }

  /// Parent directory within the content root, if any.
  public var contentDirectory: String? {
    let parent = (path as NSString).deletingLastPathComponent
    return parent.isEmpty ? nil : parent
  }

  public var href: String {
    Self.href(forPath: path)
  }

  public static func href(forPath path: String) -> String {
    let encoded = path.split(separator: "/").map { segment in
      segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(segment)
    }.joined(separator: "/")
    return "/content/\(encoded)"
  }

  public init(path: String, title: String, isPrivate: Bool, isHome: Bool) {
    self.path = path
    self.title = title
    self.isPrivate = isPrivate
    self.isHome = isHome
  }
}

public struct ContentNodeGroup: Sendable, Equatable {
  public var directory: String?
  public var nodes: [ContentNode]

  public var label: String {
    guard let directory else { return "Root" }
    return
      directory
      .split(separator: "/")
      .map { ContentStore.humanizedName(String($0)) }
      .joined(separator: " / ")
  }
}

struct ContentMeta: Codable, Sendable {
  var title: String?
}
