import Foundation

/// A WASM app page that is not backed by a markdown file.
public struct AppPage: Sendable, Equatable, Identifiable {
  public var slug: String
  public var title: String
  public var groupLabel: String
  public var isPrivate: Bool

  public var id: String { slug }

  public init(slug: String, title: String, groupLabel: String, isPrivate: Bool = false) {
    self.slug = slug
    self.title = title
    self.groupLabel = groupLabel
    self.isPrivate = isPrivate
  }
}

/// Hand-authored WASM pages registered in navigation.
public enum AppPages {
  public static let all: [AppPage] = [
    AppPage(slug: "Canvas", title: "Canvas", groupLabel: "Apps")
  ]

  public static func page(slug: String) -> AppPage? {
    all.first { $0.slug == slug }
  }

  public static func visiblePages(isAuthenticated: Bool) -> [AppPage] {
    all.filter { !$0.isPrivate || isAuthenticated }
  }
}

/// Resolved target for wasm post routes — markdown post or app page.
public struct WasmPage: Sendable, Equatable {
  public var slug: String
  public var title: String
  public var isLogin: Bool

  public init(slug: String, title: String, isLogin: Bool = false) {
    self.slug = slug
    self.title = title
    self.isLogin = isLogin
  }
}

extension ContentStore {
  /// Slugs with embedded wasm that should use client-side wasm loading in nav.
  public func navWasmSlugs(fromEmbedded embedded: Set<String>) -> Set<String> {
    guard !embedded.isEmpty else { return [] }
    var slugs = Set(
      posts
        .filter { !$0.isLogin && embedded.contains($0.slug) }
        .map(\.slug)
    )
    for page in AppPages.all where embedded.contains(page.slug) {
      slugs.insert(page.slug)
    }
    return slugs
  }
}
