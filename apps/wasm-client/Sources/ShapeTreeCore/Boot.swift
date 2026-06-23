import JavaScriptKit

enum Boot {
  static func run() {
    Nav.fetchAndRender()
    stripSignedInQuery()
    routeCurrentURL()
  }

  private static func routeCurrentURL() {
    let pathname = locationPathname()

    if pathname == "/login" {
      let next = queryParam("next")
      replaceHistory(state: loginState(next: next), path: pathname + locationSearch())
      Router.showLogin(next: next, pushState: false)
      return
    }

    if pathname == "/auth/check-email" {
      replaceHistory(state: checkEmailState(), path: pathname)
      Router.showCheckEmail(pushState: false)
      return
    }

    if pathname == "/auth/verify" {
      let token = queryParam("token")
      let next = queryParam("next")
      replaceHistory(state: verifyState(token: token, next: next), path: pathname + locationSearch())
      Router.showVerify(token: token, next: next, pushState: false)
      return
    }

    if let contentPath = contentPathFromBrowserPath(pathname) {
      let browserPath = pathname
      replaceHistory(
        state: nodeState(path: contentPath, browserPath: browserPath),
        path: browserPath
      )
      Router.mountContent(path: contentPath, title: nil, browserPath: browserPath, pushState: false)
      return
    }

    if locationIsRoot() {
      let indexPath = bodyDataset("indexPath") ?? "Home"
      let browserPath = "/"
      replaceHistory(state: nodeState(path: indexPath, browserPath: browserPath), path: browserPath)
      Router.mountContent(
        path: indexPath,
        title: bodyDataset("siteTitle"),
        browserPath: browserPath,
        pushState: false
      )
    }
  }

  private static func contentPathFromBrowserPath(_ pathname: String) -> String? {
    let prefix = "/content/"
    guard pathname.hasPrefix(prefix) else { return nil }
    let encoded = String(pathname.dropFirst(prefix.count))
    guard !encoded.isEmpty else { return nil }
    return decodeContentPath(encoded)
  }

  private static func decodeContentPath(_ encoded: String) -> String {
    encoded.split(separator: "/").map { segment in
      (try? decodeURIComponent(String(segment))) ?? String(segment)
    }.joined(separator: "/")
  }

  private static func queryParam(_ name: String) -> String? {
    nonEmpty(readQueryParam(name))
  }

  private static func nodeState(path: String, browserPath: String) -> JSObject {
    let state = JSObject()
    state.node = .boolean(true)
    state.contentPath = .string(path)
    state.path = .string(browserPath)
    return state
  }

  private static func loginState(next: String?) -> JSObject {
    let state = JSObject()
    state.login = .boolean(true)
    if let next { state.next = .string(next) }
    return state
  }

  private static func verifyState(token: String?, next: String?) -> JSObject {
    let state = JSObject()
    state.verify = .boolean(true)
    if let token { state.token = .string(token) }
    if let next { state.next = .string(next) }
    return state
  }

  private static func checkEmailState() -> JSObject {
    let state = JSObject()
    state.checkEmail = .boolean(true)
    return state
  }

  private static func stripSignedInQuery() {
    let search = locationSearch()
    guard let params = try? createURLSearchParams(search) else { return }
    guard (try? params.has("signed-in")) == true else { return }
    try? params.delete("signed-in")
    let qs = (try? params.toString()) ?? ""
    let path = locationPathname() + (qs.isEmpty ? "" : "?\(qs)")
    let state = (try? webHistory.state) ?? JSObject()
    replaceHistory(state: state, path: path)
  }
}

func readQueryParam(_ name: String) -> String? {
  let search = locationSearch()
  guard let params = try? createURLSearchParams(search) else { return nil }
  return try? params.get(name)
}

func nonEmpty(_ value: String?) -> String? {
  guard let value, !value.isEmpty else { return nil }
  return value
}
