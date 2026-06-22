import JavaScriptKit

enum Router {
  static func nodeWasmURL(slug: String) -> String {
    "/wasm/wasms/\(encodeURIComponent(slug))"
  }

  static func postPath(slug: String) -> String {
    "/wasm/posts/\(encodeURIComponent(slug))"
  }

  /// Fetches and instantiates a node wasm into `#main`, updating title and history.
  static func mountNode(slug: String, title: String?, path: String?, pushState: Bool) {
    guard let main = element("main") else { return }
    setHTML(main, "<p>Loading…</p>")
    setLoading(true)
    let resolvedPath = path ?? postPath(slug: slug)
    mountModule(nodeWasmURL(slug: slug)) { result in
      setLoading(false)
      if result.status == 404 || !result.ok {
        renderNotFound(path: resolvedPath, pushState: pushState)
        return
      }
      setDocumentTitle(title ?? slug)
      if pushState {
        let state = JSObject()
        state.node = .boolean(true)
        state.slug = .string(JSString(slug))
        if let title { state.title = .string(JSString(title)) }
        state.path = .string(JSString(resolvedPath))
        pushHistory(state: state, path: resolvedPath)
      }
    }
  }

  static func renderNotFound(path: String, pushState: Bool) {
    guard let main = element("main") else { return }
    setHTML(main, "<article><h1>404</h1><p>Page not found.</p></article>")
    setDocumentTitle("Not Found")
    if pushState {
      let state = JSObject()
      state.notFound = .boolean(true)
      state.path = .string(JSString(path))
      pushHistory(state: state, path: path)
    }
  }

  static func showLogin(next: String?, pushState: Bool) {
    guard let main = element("main") else { return }
    AuthViews.renderLogin(into: main, next: next)
    setDocumentTitle("Sign in")
    if pushState {
      let state = JSObject()
      state.login = .boolean(true)
      if let next { state.next = .string(JSString(next)) }
      let path = next.map { "/login?next=\(encodeURIComponent($0))" } ?? "/login"
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
      let state = JSObject()
      state.verify = .boolean(true)
      if let token { state.token = .string(JSString(token)) }
      if let next { state.next = .string(JSString(next)) }
      pushHistory(state: state, path: locationPathname() + locationSearch())
    }
  }

  static func showCheckEmail(pushState: Bool) {
    guard let main = element("main") else { return }
    AuthViews.renderCheckEmail(into: main)
    setDocumentTitle("Check your email")
    if pushState {
      let state = JSObject()
      state.checkEmail = .boolean(true)
      pushHistory(state: state, path: locationPathname())
    }
  }

  static func registerHistory() {
    let popstate = JSClosure { arguments in
      guard let event = arguments[0].object else { return .undefined }
      let state: JSValue = event.state
      if state.node.boolean == true, let slug = state.slug.string {
        let title = state.title.string
        let path = state.path.string
        mountNode(slug: slug, title: title, path: path, pushState: false)
      } else if state.login.boolean == true {
        let next = state.next.string
        showLogin(next: next, pushState: false)
      } else if state.verify.boolean == true {
        let token = state.token.string
        let next = state.next.string
        showVerify(token: token, next: next, pushState: false)
      } else if state.checkEmail.boolean == true {
        showCheckEmail(pushState: false)
      } else if state.notFound.boolean == true {
        renderNotFound(path: state.path.string ?? locationPathname(), pushState: false)
      }
      return .undefined
    }
    ShapeTreeCore.listeners.append(popstate)
    _ = JSObject.global.addEventListener!("popstate", JSValue.object(popstate))
  }
}
