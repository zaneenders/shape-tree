import JavaScriptKit

public func createElement(
  _ tag: String,
  className: String? = nil,
  id: String? = nil,
  innerText: String? = nil,
  attributes: [String: String] = [:]
) -> JSValue {
  let document = JSObject.global.document
  let element = document.createElement(tag)
  if let className {
    element.className = .string(className)
  }
  if let id {
    element.id = .string(id)
  }
  if let innerText {
    element.innerText = .string(innerText)
  }
  for (name, value) in attributes {
    _ = element.setAttribute(name, value)
  }
  return element
}

public func append(_ child: JSValue, to parent: JSValue) {
  _ = parent.appendChild(child)
}

public func setAttribute(_ element: JSValue, _ name: String, _ value: String) {
  _ = element.setAttribute(name, value)
}

public func setInnerText(_ element: JSValue, _ text: String) {
  element.innerText = .string(text)
}

public func setInnerHTML(_ element: JSValue, _ html: String) {
  element.innerHTML = .string(html)
}

public func clearElement(_ element: JSValue) {
  element.innerHTML = .string("")
}

public func setHidden(_ element: JSValue, _ hidden: Bool) {
  element.hidden = .boolean(hidden)
}

public func locationPathname() -> String {
  JSObject.global.location.pathname.string ?? "/"
}

public func replaceHistoryPath(_ path: String) {
  _ = JSObject.global.history.replaceState(JSValue.null, "", path)
}

public func pushHistoryPath(_ path: String) {
  _ = JSObject.global.history.pushState(JSValue.null, "", path)
}

public func registerTabListResetHandler(for path: String, handler: @escaping () -> Void) {
  let window = JSObject.global.window
  var handlers = window.tabListResetHandlers.object ?? JSObject()
  handlers[path] = .object(
    JSClosure { _ -> JSValue in
      handler()
      return .undefined
    }
  )
  window.tabListResetHandlers = .object(handlers)
}

public func resetTabContentList(path: String) {
  guard let handlers = JSObject.global.window.tabListResetHandlers.object,
    let reset = handlers[path].function
  else {
    return
  }
  reset()
}

public func elementById(_ id: String) -> JSValue? {
  let document = JSObject.global.document
  return document.getElementById(id).object.map { .object($0) }
}

public func documentBody() -> JSValue {
  let document = JSObject.global.document
  return document.body
}

public struct FeatureShell {
  public let wrapper: JSValue
  public let status: JSValue
}

public func mountFeatureShell(
  into container: JSValue,
  className: String,
  loadingMessage: String
) -> FeatureShell {
  let wrapper = createElement("div", className: className)
  append(wrapper, to: container)
  let status = createElement("p", className: "status", innerText: loadingMessage)
  append(status, to: wrapper)
  return FeatureShell(wrapper: wrapper, status: status)
}
