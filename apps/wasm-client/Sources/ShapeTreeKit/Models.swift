import JavaScriptKit

// MARK: - Shell ↔ page bus

@JS public struct PageMessage {
  public var kind: String
  public var path: String?
  public var payload: String?

  @JS public init(kind: String, path: String?, payload: String?) {
    self.kind = kind
    self.path = path
    self.payload = payload
  }
}

@JS public struct ShellMessage {
  public var kind: String
  public var payload: String?

  @JS public init(kind: String, payload: String?) {
    self.kind = kind
    self.payload = payload
  }
}

public enum PageMessageKind {
  public static let ready = "ready"
  public static let setTitle = "setTitle"
  public static let navigate = "navigate"
}

public enum ShellMessageKind {
  public static let teardown = "teardown"
}

// MARK: - Nav API (`GET /api/get-nav-content`)

@JS public struct NavContentItem {
  public var path: String
  public var slug: String
  public var title: String
  public var href: String
  public var hasWasm: Bool

  @JS public init(path: String, slug: String, title: String, href: String, hasWasm: Bool) {
    self.path = path
    self.slug = slug
    self.title = title
    self.href = href
    self.hasWasm = hasWasm
  }
}

@JS public struct NavSignInAction {
  public var href: String
  public var label: String
  public var spa: Bool

  @JS public init(href: String, label: String, spa: Bool) {
    self.href = href
    self.label = label
    self.spa = spa
  }
}

@JS public struct NavContentGroup {
  public var label: String
  public var directory: String?
  public var items: [NavContentItem]

  @JS public init(label: String, directory: String?, items: [NavContentItem]) {
    self.label = label
    self.directory = directory
    self.items = items
  }
}

@JS public struct NavViewer {
  public var isAuthenticated: Bool
  public var email: String?

  @JS public init(isAuthenticated: Bool, email: String?) {
    self.isAuthenticated = isAuthenticated
    self.email = email
  }
}

@JS public struct NavContentResponse {
  public var siteTitle: String
  public var viewer: NavViewer
  public var home: NavContentItem
  public var groups: [NavContentGroup]
  public var signIn: NavSignInAction?

  @JS public init(
    siteTitle: String,
    viewer: NavViewer,
    home: NavContentItem,
    groups: [NavContentGroup],
    signIn: NavSignInAction?
  ) {
    self.siteTitle = siteTitle
    self.viewer = viewer
    self.home = home
    self.groups = groups
    self.signIn = signIn
  }
}

// MARK: - `history.state` / `pushState` payloads

@JS public struct HistoryState {
  public var node: Bool?
  public var contentPath: String?
  public var title: String?
  public var path: String?
  public var login: Bool?
  public var verify: Bool?
  public var checkEmail: Bool?
  public var notFound: Bool?
  public var next: String?
  public var token: String?

  @JS public init(
    node: Bool? = nil,
    contentPath: String? = nil,
    title: String? = nil,
    path: String? = nil,
    login: Bool? = nil,
    verify: Bool? = nil,
    checkEmail: Bool? = nil,
    notFound: Bool? = nil,
    next: String? = nil,
    token: String? = nil
  ) {
    self.node = node
    self.contentPath = contentPath
    self.title = title
    self.path = path
    self.login = login
    self.verify = verify
    self.checkEmail = checkEmail
    self.notFound = notFound
    self.next = next
    self.token = token
  }
}
