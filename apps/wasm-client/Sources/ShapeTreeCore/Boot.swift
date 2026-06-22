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
      Router.mountContent(path: indexPath, title: bodyDataset("siteTitle"), browserPath: browserPath, pushState: false)
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
      JSObject.global.decodeURIComponent!(String(segment)).string ?? String(segment)
    }.joined(separator: "/")
  }

  private static func queryParam(_ name: String) -> String? {
    nonEmpty(readQueryParam(name))
  }

  private static func nodeState(path: String, browserPath: String) -> JSObject {
    let state = JSObject()
    state.node = .boolean(true)
    state.contentPath = .string(JSString(path))
    state.path = .string(JSString(browserPath))
    return state
  }

  private static func loginState(next: String?) -> JSObject {
    let state = JSObject()
    state.login = .boolean(true)
    if let next { state.next = .string(JSString(next)) }
    return state
  }

  private static func verifyState(token: String?, next: String?) -> JSObject {
    let state = JSObject()
    state.verify = .boolean(true)
    if let token { state.token = .string(JSString(token)) }
    if let next { state.next = .string(JSString(next)) }
    return state
  }

  private static func checkEmailState() -> JSObject {
    let state = JSObject()
    state.checkEmail = .boolean(true)
    return state
  }

  /// After magic-link verify the server redirects to `next?signed-in=1`; nav was
  /// already fetched with the authed cookie, so just drop the marker from the URL.
  private static func stripSignedInQuery() {
    let search = locationSearch()
    guard let constructor = JSObject.global.URLSearchParams.function else { return }
    let params = constructor.new(JSValue.string(JSString(search)))
    guard params.has!("signed-in").boolean == true else { return }
    _ = params.delete!("signed-in")
    let qs = params.toString!().string ?? ""
    let path = locationPathname() + (qs.isEmpty ? "" : "?\(qs)")
    let current: JSValue = JSObject.global.history.state
    let state = current.object ?? JSObject()
    replaceHistory(state: state, path: path)
  }
}

func readQueryParam(_ name: String) -> String? {
  let search = locationSearch()
  guard let constructor = JSObject.global.URLSearchParams.function else { return nil }
  let params = constructor.new(JSValue.string(JSString(search)))
  let value = params.get!(name)
  guard !value.isNull, !value.isUndefined else { return nil }
  return value.string
}

func nonEmpty(_ value: String?) -> String? {
  guard let value, !value.isEmpty else { return nil }
  return value
}
