import JavaScriptKit

enum Router {
  static func contentWasmURL(path: String) -> String {
    let encoded = encodedContentPath(path)
    return "/content/\(encoded).wasm"
  }

  static func contentBrowserPath(path: String, isHome: Bool = false) -> String {
    if isHome { return "/" }
    return "/content/\(encodedContentPath(path))"
  }

  static func mountContent(path: String, title: String?, browserPath: String?, pushState: Bool) {
    guard let main = element("main") else { return }
    setHTML(main, "<p>Loading…</p>")
    setLoading(true)
    let resolvedPath = browserPath ?? contentBrowserPath(path: path)
    mountModule(contentWasmURL(path: path)) { result in
      setLoading(false)
      if result.status == 404 || !result.ok {
        renderNotFound(path: resolvedPath, pushState: pushState)
        return
      }
      setDocumentTitle(title ?? displayTitle(forPath: path))
      if pushState {
        pushHistory(
          state: nodeState(path: path, title: title, browserPath: resolvedPath),
          path: resolvedPath
        )
      }
    }
  }

  static func renderNotFound(path: String, pushState: Bool) {
    guard let main = element("main") else { return }
    setHTML(main, "<article><h1>404</h1><p>Page not found.</p></article>")
    setDocumentTitle("Not Found")
    if pushState {
      var state = HistoryState()
      state.notFound = true
      state.path = path
      pushHistory(state: state, path: path)
    }
  }

  static func showLogin(next: String?, pushState: Bool) {
    guard let main = element("main") else { return }
    AuthViews.renderLogin(into: main, next: next)
    setDocumentTitle("Sign in")
    if pushState {
      var state = HistoryState()
      state.login = true
      state.next = next
      let path = next.map { "/login?next=\(encodedPathComponent($0))" } ?? "/login"
      pushHistory(state: state, path: path)
    }
  }

  static func showVerify(token: String?, next: String?, pushState: Bool) {
    guard let main = element("main") else { return }
    if let token, !token.isEmpty {
      AuthViews.renderVerifyConfirm(into: main, token: token, next: next)
      setDocumentTitle("Confirm sign in")
    } else {
      AuthViews.renderVerifyFailed(into: main)
      setDocumentTitle("Sign in failed")
    }
    if pushState {
      var state = HistoryState()
      state.verify = true
      state.token = token
      state.next = next
      pushHistory(state: state, path: locationPathname() + locationSearch())
    }
  }

  static func showCheckEmail(pushState: Bool) {
    guard let main = element("main") else { return }
    AuthViews.renderCheckEmail(into: main)
    setDocumentTitle("Check your email")
    if pushState {
      var state = HistoryState()
      state.checkEmail = true
      pushHistory(state: state, path: locationPathname())
    }
  }

  static func registerHistory() {
    try? webWindow.addEventListener("popstate") { event in
      guard let state = historyState(from: event) else { return }
      if state.node == true, let path = state.contentPath {
        mountContent(path: path, title: state.title, browserPath: state.path, pushState: false)
      } else if state.login == true {
        showLogin(next: state.next, pushState: false)
      } else if state.verify == true {
        showVerify(token: state.token, next: state.next, pushState: false)
      } else if state.checkEmail == true {
        showCheckEmail(pushState: false)
      } else if state.notFound == true {
        renderNotFound(path: state.path ?? locationPathname(), pushState: false)
      }
    }
  }

  private static func nodeState(path: String, title: String?, browserPath: String) -> HistoryState {
    var state = HistoryState()
    state.node = true
    state.contentPath = path
    state.title = title
    state.path = browserPath
    return state
  }

  private static func displayTitle(forPath path: String) -> String {
    path.split(separator: "/").last.map(String.init) ?? path
  }

  private static func encodedContentPath(_ path: String) -> String {
    path.split(separator: "/").map { encodedPathComponent(String($0)) }.joined(separator: "/")
  }
}
