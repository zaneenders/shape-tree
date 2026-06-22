import JavaScriptKit

enum Boot {
  static func run() {
    Nav.fetchAndRender()
    stripSignedInQuery()

    if bodyFlag("bootLogin") {
      let next = nonEmpty(bodyDataset("loginNext"))
      let state = JSObject()
      state.login = .boolean(true)
      if let next { state.next = .string(JSString(next)) }
      replaceHistory(state: state, path: locationPathname() + locationSearch())
      Router.showLogin(next: next, pushState: false)
      return
    }

    if bodyFlag("bootVerify") {
      let token = nonEmpty(bodyDataset("verifyToken"))
      let next = nonEmpty(bodyDataset("verifyNext"))
      let state = JSObject()
      state.verify = .boolean(true)
      if let token { state.token = .string(JSString(token)) }
      if let next { state.next = .string(JSString(next)) }
      replaceHistory(state: state, path: locationPathname() + locationSearch())
      Router.showVerify(token: token, next: next, pushState: false)
      return
    }

    if bodyFlag("bootCheckEmail") {
      let state = JSObject()
      state.checkEmail = .boolean(true)
      replaceHistory(state: state, path: locationPathname())
      Router.showCheckEmail(pushState: false)
      return
    }

    if let slug = bodyDataset("initialWasmSlug") {
      let title = bodyDataset("initialWasmTitle")
      let path = locationPathname()
      replaceHistory(state: nodeState(slug: slug, title: title, path: path), path: path)
      Router.mountNode(slug: slug, title: title, path: path, pushState: false)
      return
    }

    if bodyFlag("bootNotFound") {
      Router.renderNotFound(path: locationPathname(), pushState: false)
      return
    }

    if let home = bodyDataset("homeSlug"), locationIsRoot() {
      let title = bodyDataset("homeTitle")
      replaceHistory(state: nodeState(slug: home, title: title, path: "/"), path: "/")
      Router.mountNode(slug: home, title: title, path: "/", pushState: false)
    }
  }

  private static func nodeState(slug: String, title: String?, path: String) -> JSObject {
    let state = JSObject()
    state.node = .boolean(true)
    state.slug = .string(JSString(slug))
    if let title { state.title = .string(JSString(title)) }
    state.path = .string(JSString(path))
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

func nonEmpty(_ value: String?) -> String? {
  guard let value, !value.isEmpty else { return nil }
  return value
}
