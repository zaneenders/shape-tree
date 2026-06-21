import Foundation

/// Session-aware viewer metadata for nav APIs.
public struct NavViewer: Codable, Sendable, Equatable {
  public var isAuthenticated: Bool
  public var email: String?

  public init(isAuthenticated: Bool, email: String? = nil) {
    self.isAuthenticated = isAuthenticated
    self.email = email
  }
}

/// A navigable content item (home, article, favorite page, etc.).
public struct NavContentItem: Codable, Sendable, Equatable {
  public var slug: String
  public var title: String
  public var href: String
  public var hasWasm: Bool

  public init(slug: String, title: String, href: String, hasWasm: Bool) {
    self.slug = slug
    self.title = title
    self.href = href
    self.hasWasm = hasWasm
  }
}

/// A directory grouping in the nav tree (e.g. Articles, Favorites).
public struct NavContentGroup: Codable, Sendable, Equatable {
  public var label: String
  public var directory: String?
  public var items: [NavContentItem]

  public init(label: String, directory: String?, items: [NavContentItem]) {
    self.label = label
    self.directory = directory
    self.items = items
  }
}

/// Sign-in action shown when the viewer is unauthenticated.
public struct NavSignInAction: Codable, Sendable, Equatable {
  public var href: String
  public var label: String
  /// When true, the client loads sign-in in `#main` instead of a full navigation.
  public var spa: Bool

  public init(href: String, label: String, spa: Bool = true) {
    self.href = href
    self.label = label
    self.spa = spa
  }
}

/// JSON body for `GET /api/get-nav-content`.
public struct NavContentResponse: Codable, Sendable, Equatable {
  public var siteTitle: String
  public var viewer: NavViewer
  public var home: NavContentItem
  public var groups: [NavContentGroup]
  public var signIn: NavSignInAction?

  public init(
    siteTitle: String,
    viewer: NavViewer,
    home: NavContentItem,
    groups: [NavContentGroup],
    signIn: NavSignInAction? = nil
  ) {
    self.siteTitle = siteTitle
    self.viewer = viewer
    self.home = home
    self.groups = groups
    self.signIn = signIn
  }
}

extension ContentStore {
  /// Builds the nav JSON payload using the same visibility rules as server-rendered navigation.
  public func navContentResponse(viewer: NavViewer, wasmSlugs: Set<String>) -> NavContentResponse {
    let index = indexPost
    let homeSlug = index?.slug ?? "Home"
    let homeTitle = siteTitle
    let home = NavContentItem(
      slug: homeSlug,
      title: homeTitle,
      href: "/",
      hasWasm: wasmSlugs.contains(homeSlug)
    )

    let groups = postGroups(includingPrivate: viewer.isAuthenticated).map { group in
      NavContentGroup(
        label: group.label,
        directory: group.directory,
        items: group.posts.map { navItem(for: $0, wasmSlugs: wasmSlugs) }
      )
    }

    let signIn: NavSignInAction? =
      viewer.isAuthenticated
      ? nil
      : NavSignInAction(href: "/login", label: "Sign in")

    return NavContentResponse(
      siteTitle: siteTitle,
      viewer: viewer,
      home: home,
      groups: groups,
      signIn: signIn
    )
  }

  private func navItem(for post: Post, wasmSlugs: Set<String>) -> NavContentItem {
    let hasWasm = wasmSlugs.contains(post.slug)
    let href =
      hasWasm
      ? "/wasm/posts/\(post.slug)"
      : post.path
    return NavContentItem(
      slug: post.slug,
      title: post.title,
      href: href,
      hasWasm: hasWasm
    )
  }
}
