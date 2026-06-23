import JavaScriptKit
import ShapeTreeKit

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

  private static func nodeState(path: String, browserPath: String) -> HistoryState {
    var state = HistoryState()
    state.node = true
    state.contentPath = path
    state.path = browserPath
    return state
  }

  private static func loginState(next: String?) -> HistoryState {
    var state = HistoryState()
    state.login = true
    state.next = next
    return state
  }

  private static func verifyState(token: String?, next: String?) -> HistoryState {
    var state = HistoryState()
    state.verify = true
    state.token = token
    state.next = next
    return state
  }

  private static func checkEmailState() -> HistoryState {
    var state = HistoryState()
    state.checkEmail = true
    return state
  }

  private static func stripSignedInQuery() {
    let search = locationSearch()
    guard let params = try? createURLSearchParams(search) else { return }
    guard (try? params.has("signed-in")) == true else { return }
    try? params.delete("signed-in")
    let qs = (try? params.toString()) ?? ""
    let path = locationPathname() + (qs.isEmpty ? "" : "?\(qs)")
    replaceHistory(state: currentHistoryState(), path: path)
  }
}
