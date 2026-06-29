import JavaScriptKit
import ShapeTreeDOM

struct AppShell {
  let routeOutlet: JSValue
  let demoTab: JSValue
  let fitTab: JSValue
  let articleTab: JSValue
  let authButton: JSValue
  let demoPanel: JSValue
  let fitPanel: JSValue
  let articlePanel: JSValue
}

enum ClientRoute: Equatable {
  case home
  case login(next: String)

  static func from(pathname: String, search: String) -> ClientRoute? {
    switch pathname {
    case "/":
      return .home
    case "/login":
      let next = normalizedNextPath(queryParam("next", in: search)) ?? "/"
      return .login(next: next)
    default:
      return nil
    }
  }

  var documentTitle: String {
    switch self {
    case .home:
      "ShapeTree · Swift WASM Demo"
    case .login:
      "Sign in"
    }
  }

  var path: String {
    switch self {
    case .home:
      "/"
    case .login(let next):
      if next == "/" {
        "/login?next=/"
      } else {
        "/login?next=\(next)"
      }
    }
  }
}

func wireClientRouter(shell: AppShell) {
  let window = JSObject.global.window
  let document = JSObject.global.document

  _ = window.addEventListener(
    "popstate",
    JSClosure { _ -> JSValue in
      syncViewToLocation(shell: shell)
      return .undefined
    }
  )

  let captureOptions = JSObject()
  captureOptions.capture = .boolean(true)
  _ = document.addEventListener(
    "click",
    JSClosure { arguments -> JSValue in
      guard let event = arguments[0].object else { return .undefined }
      if event.defaultPrevented.boolean == true { return .undefined }
      if let button = event.button.number, button != 0 { return .undefined }
      if event.ctrlKey.boolean == true || event.metaKey.boolean == true
        || event.shiftKey.boolean == true || event.altKey.boolean == true
      {
        return .undefined
      }

      guard let anchor = closestAnchor(from: event.target) else { return .undefined }
      if anchor.target.string == "_blank" { return .undefined }

      guard let href = anchor.href.string, !href.isEmpty else { return .undefined }
      guard let url = JSObject.global.URL.object?.new(href, JSObject.global.location.href).object else {
        return .undefined
      }
      if url.origin.string != JSObject.global.location.origin.string { return .undefined }

      let pathname = url.pathname.string ?? "/"
      let search = url.search.string ?? ""
      guard let route = ClientRoute.from(pathname: pathname, search: search) else { return .undefined }

      _ = event.preventDefault!()
      _ = event.stopPropagation!()
      showRoute(route, shell: shell, updateHistory: true)
      return .undefined
    },
    captureOptions
  )
}

func renderInitialView(shell: AppShell) {
  let location = JSObject.global.location
  let pathname = location.pathname.string ?? "/"
  let search = location.search.string ?? ""

  if let route = ClientRoute.from(pathname: pathname, search: search) {
    showRoute(route, shell: shell, updateHistory: false)
    return
  }

  if let props = readPageProps(), !props.page.isEmpty {
    clearElement(shell.routeOutlet)
    renderAuthView(into: shell.routeOutlet, props: props, shell: shell)
    selectDemoTab(shell: shell)
    return
  }

  showRoute(.home, shell: shell, updateHistory: false)
}

func navigateToHome(shell: AppShell) {
  showRoute(.home, shell: shell, updateHistory: true)
}

func navigateToLogin(shell: AppShell, next: String = "/") {
  let safeNext = normalizedNextPath(next) ?? "/"
  showRoute(.login(next: safeNext), shell: shell, updateHistory: true)
}

private func showRoute(_ route: ClientRoute, shell: AppShell, updateHistory: Bool) {
  clearElement(shell.routeOutlet)

  switch route {
  case .home:
    renderDemoContent(into: shell.routeOutlet)
    selectDemoTab(shell: shell)
  case .login(let next):
    renderAuthView(
      into: shell.routeOutlet,
      props: PageProps(page: "login", next: next, token: ""),
      shell: shell
    )
    selectDemoTab(shell: shell)
  }

  JSObject.global.document.title = .string(route.documentTitle)

  if updateHistory {
    _ = JSObject.global.history.pushState(JSValue.null, "", route.path)
  }
}

private func syncViewToLocation(shell: AppShell) {
  let location = JSObject.global.location
  let pathname = location.pathname.string ?? "/"
  let search = location.search.string ?? ""

  if let route = ClientRoute.from(pathname: pathname, search: search) {
    showRoute(route, shell: shell, updateHistory: false)
  }
}

private func closestAnchor(from target: JSValue) -> JSObject? {
  var element = target
  while !element.isUndefined {
    if let object = element.object {
      if object.tagName.string?.lowercased() == "a" {
        return object
      }
      guard let parent = object.parentElement.object else { break }
      element = .object(parent)
    } else {
      break
    }
  }
  return nil
}

private func queryParam(_ name: String, in search: String) -> String? {
  guard !search.isEmpty else { return nil }
  let query = search.hasPrefix("?") ? String(search.dropFirst()) : search
  for pair in query.split(separator: "&") {
    let parts = pair.split(separator: "=", maxSplits: 1)
    guard parts.count == 2, parts[0] == Substring(name) else { continue }
    return String(parts[1])
  }
  return nil
}

private func normalizedNextPath(_ raw: String?) -> String? {
  guard let raw, raw.hasPrefix("/"), !raw.hasPrefix("//") else {
    return nil
  }
  return raw
}
