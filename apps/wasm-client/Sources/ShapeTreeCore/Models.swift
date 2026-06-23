import JavaScriptKit

// MARK: - Nav API (`GET /api/get-nav-content`)

@JS struct NavContentItem {
  var path: String
  var slug: String
  var title: String
  var href: String
  var hasWasm: Bool
}

@JS struct NavSignInAction {
  var href: String
  var label: String
  var spa: Bool
}

@JS struct NavContentGroup {
  var label: String
  var directory: String?
  var items: [NavContentItem]
}

@JS struct NavViewer {
  var isAuthenticated: Bool
  var email: String?
}

@JS struct NavContentResponse {
  var siteTitle: String
  var viewer: NavViewer
  var home: NavContentItem
  var groups: [NavContentGroup]
  var signIn: NavSignInAction?
}

// MARK: - `history.state` / `pushState` payloads

@JS struct HistoryState {
  var node: Bool?
  var contentPath: String?
  var title: String?
  var path: String?
  var login: Bool?
  var verify: Bool?
  var checkEmail: Bool?
  var notFound: Bool?
  var next: String?
  var token: String?
}
