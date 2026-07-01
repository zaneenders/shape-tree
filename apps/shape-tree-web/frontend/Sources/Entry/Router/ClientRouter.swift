import JavaScriptKit
import ShapeTreeDOM

struct AppShell {
  let routeOutlet: JSValue
  let demoTab: JSValue
  let fitTab: JSValue
  let articlesTab: JSValue
  let favoritesTab: JSValue
  let authButton: JSValue
  let demoPanel: JSValue
  let fitPanel: JSValue
  let articlesPanel: JSValue
  let favoritesPanel: JSValue
}

enum ClientRoute: Equatable {
  case home
  case login(next: String)
  case checkEmail
  case verify(token: String, next: String)

  var isAuthFlow: Bool {
    switch self {
    case .home:
      false
    case .login, .checkEmail, .verify:
      true
    }
  }

  static func from(pathname: String, search: String) -> ClientRoute? {
    switch pathname {
    case "/":
      return .home
    case "/login":
      let next = normalizedNextPath(queryParam("next", in: search)) ?? "/"
      return .login(next: next)
    case "/auth/check-email":
      return .checkEmail
    case "/auth/verify":
      return .verify(
        token: queryParam("token", in: search) ?? "",
        next: normalizedNextPath(queryParam("next", in: search)) ?? "/"
      )
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
    case .checkEmail:
      "Check your email"
    case .verify(let token, _):
      token.isEmpty ? "Sign-in link invalid" : "Confirm sign in"
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
    case .checkEmail:
      "/auth/check-email"
    case .verify(let token, let next):
      verifyPath(token: token, next: next)
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

  showRoute(.home, shell: shell, updateHistory: false)
}

func navigateToHome(shell: AppShell) {
  showRoute(.home, shell: shell, updateHistory: true)
}

func navigateToLogin(shell: AppShell, next: String = "/") {
  let safeNext = normalizedNextPath(next) ?? "/"
  showRoute(.login(next: safeNext), shell: shell, updateHistory: true)
}

func navigateToCheckEmail(shell: AppShell) {
  showRoute(.checkEmail, shell: shell, updateHistory: true)
}

func navigateToVerify(shell: AppShell, token: String = "", next: String = "/") {
  let safeNext = normalizedNextPath(next) ?? "/"
  showRoute(.verify(token: token, next: safeNext), shell: shell, updateHistory: true)
}

func navigateAfterSignIn(shell: AppShell, next: String) {
  let safeNext = normalizedNextPath(next) ?? "/"
  if safeNext == "/" {
    navigateToHome(shell: shell)
    return
  }
  if let route = ClientRoute.from(pathname: safeNext, search: "") {
    showRoute(route, shell: shell, updateHistory: true)
    return
  }
  navigateToHome(shell: shell)
}

private func showRoute(_ route: ClientRoute, shell: AppShell, updateHistory: Bool) {
  let wasOnAuthFlow = JSObject.global.window.onAuthFlowRoute.boolean == true
  JSObject.global.window.onAuthFlowRoute = .boolean(route.isAuthFlow)
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
  case .checkEmail:
    renderAuthView(
      into: shell.routeOutlet,
      props: PageProps(page: "check-email", next: "/", token: ""),
      shell: shell
    )
    selectDemoTab(shell: shell)
  case .verify(let token, let next):
    renderAuthView(
      into: shell.routeOutlet,
      props: PageProps(page: "verify", next: next, token: token),
      shell: shell
    )
    selectDemoTab(shell: shell)
  }

  JSObject.global.document.title = .string(route.documentTitle)

  if updateHistory {
    _ = JSObject.global.history.pushState(JSValue.null, "", route.path)
  }

  if wasOnAuthFlow && !route.isAuthFlow {
    refreshSessionTabs(shell: shell)
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

func queryParam(_ name: String, in search: String) -> String? {
  guard !search.isEmpty else { return nil }
  let query = search.hasPrefix("?") ? String(search.dropFirst()) : search
  for pair in query.split(separator: "&") {
    let parts = pair.split(separator: "=", maxSplits: 1)
    guard parts.count == 2, parts[0] == Substring(name) else { continue }
    return percentDecode(String(parts[1]))
  }
  return nil
}

private func normalizedNextPath(_ raw: String?) -> String? {
  guard let raw, raw.hasPrefix("/"), !raw.hasPrefix("//") else {
    return nil
  }
  return raw
}

private func verifyPath(token: String, next: String) -> String {
  if token.isEmpty {
    return "/auth/verify"
  }
  var path = "/auth/verify?token=\(formURLEncode(token))"
  if next != "/" {
    path += "&next=\(formURLEncode(next))"
  }
  return path
}

private func percentDecode(_ value: String) -> String {
  var result = ""
  var index = value.startIndex
  while index < value.endIndex {
    let char = value[index]
    if char == "%", value.distance(from: index, to: value.endIndex) >= 3 {
      let next = value.index(index, offsetBy: 1)
      let end = value.index(index, offsetBy: 3)
      let hex = String(value[next..<end])
      if let code = UInt8(hex, radix: 16) {
        result.append(Character(UnicodeScalar(code)))
        index = end
        continue
      }
    }
    if char == "+" {
      result.append(" ")
    } else {
      result.append(char)
    }
    index = value.index(after: index)
  }
  return result
}

func formURLEncode(_ value: String) -> String {
  let hexDigits = Array("0123456789ABCDEF")
  var result = ""
  for byte in value.utf8 {
    switch byte {
    case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F, 0x7E:
      result.append(Character(UnicodeScalar(byte)))
    default:
      result.append("%")
      result.append(hexDigits[Int(byte >> 4)])
      result.append(hexDigits[Int(byte & 0x0F)])
    }
  }
  return result
}
