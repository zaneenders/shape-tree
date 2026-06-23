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
        pushHistory(state: nodeState(path: path, title: title, browserPath: resolvedPath), path: resolvedPath)
      }
    }
  }

  static func renderNotFound(path: String, pushState: Bool) {
    guard let main = element("main") else { return }
    setHTML(main, "<article><h1>404</h1><p>Page not found.</p></article>")
    setDocumentTitle("Not Found")
    if pushState {
      let state = historyState()
      state.notFound = .boolean(true)
      state.path = .string(path)
      pushHistory(state: state, path: path)
    }
  }

  static func showLogin(next: String?, pushState: Bool) {
    guard let main = element("main") else { return }
    AuthViews.renderLogin(into: main, next: next)
    setDocumentTitle("Sign in")
    if pushState {
      let state = historyState()
      state.login = .boolean(true)
      if let next { state.next = .string(next) }
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
      let state = historyState()
      state.verify = .boolean(true)
      if let token { state.token = .string(token) }
      if let next { state.next = .string(next) }
      pushHistory(state: state, path: locationPathname() + locationSearch())
    }
  }

  static func showCheckEmail(pushState: Bool) {
    guard let main = element("main") else { return }
    AuthViews.renderCheckEmail(into: main)
    setDocumentTitle("Check your email")
    if pushState {
      let state = historyState()
      state.checkEmail = .boolean(true)
      pushHistory(state: state, path: locationPathname())
    }
  }

  static func registerHistory() {
    try? webWindow.addEventListener("popstate") { event in
      guard let state = Bridge.eventState(event) else { return }
      if state.node.boolean == true, let path = Bridge.jsObjectPropertyString(state, "contentPath") {
        let title = Bridge.jsObjectPropertyString(state, "title")
        let browserPath = Bridge.jsObjectPropertyString(state, "path")
        mountContent(path: path, title: title, browserPath: browserPath, pushState: false)
      } else if state.login.boolean == true {
        let next = Bridge.jsObjectPropertyString(state, "next")
        showLogin(next: next, pushState: false)
      } else if state.verify.boolean == true {
        let token = Bridge.jsObjectPropertyString(state, "token")
        let next = Bridge.jsObjectPropertyString(state, "next")
        showVerify(token: token, next: next, pushState: false)
      } else if state.checkEmail.boolean == true {
        showCheckEmail(pushState: false)
      } else if state.notFound.boolean == true {
        renderNotFound(path: Bridge.jsObjectPropertyString(state, "path") ?? locationPathname(), pushState: false)
      }
    }
  }

  private static func nodeState(path: String, title: String?, browserPath: String) -> JSObject {
    let state = historyState()
    state.node = .boolean(true)
    state.contentPath = .string(path)
    if let title { state.title = .string(title) }
    state.path = .string(browserPath)
    return state
  }

  private static func displayTitle(forPath path: String) -> String {
    path.split(separator: "/").last.map(String.init) ?? path
  }

  private static func encodedContentPath(_ path: String) -> String {
    path.split(separator: "/").map { encodedPathComponent(String($0)) }.joined(separator: "/")
  }
}

private func historyState() -> JSObject {
  JSObject()
}
