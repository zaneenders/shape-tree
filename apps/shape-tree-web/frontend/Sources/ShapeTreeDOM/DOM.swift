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
