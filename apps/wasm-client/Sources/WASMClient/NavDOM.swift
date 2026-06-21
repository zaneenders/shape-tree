import JavaScriptKit

func jsEquals(_ lhs: JSValue, _ rhs: JSString) -> Bool {
  guard let left = lhs.jsString else { return false }
  return left == rhs
}

func jsEquals(_ lhs: JSValue, _ rhs: String) -> Bool {
  jsEquals(lhs, JSString(rhs))
}

func hasClass(_ element: JSObject, _ className: String) -> Bool {
  guard let classList = element.classList.object else { return false }
  return classList.contains!(className).boolean == true
}

func isContained(_ parent: JSObject, _ child: JSObject) -> Bool {
  parent.contains!(child).boolean == true
}

func navigationRoot(in document: JSValue) -> JSObject? {
  document.getElementById("styled-navigation").object
}

func checkedDisclosures(in nav: JSObject) -> [JSObject] {
  let nodeList = nav.querySelectorAll!("input.nav-disclosure[type=\"checkbox\"]:checked")
  let length = Int(nodeList.length.number ?? 0)
  var values: [JSObject] = []
  values.reserveCapacity(length)
  for index in 0..<length {
    if let value = nodeList.item(Double(index)).object {
      values.append(value)
    }
  }
  return values
}

func ensureBackdrop(in document: JSValue) -> JSObject? {
  if let existing = document.getElementById("nav-backdrop").object {
    return existing
  }
  guard let body = document.body.object else { return nil }
  guard let backdrop = document.createElement("div").object else { return nil }
  backdrop.id = .string("nav-backdrop")
  _ = backdrop.setAttribute!("aria-hidden", "true")
  let backdropClick = JSClosure { _ in
    NavDismiss.log("backdrop click")
    closeAll(in: document)
    return .undefined
  }
  NavDismiss.listeners.append(backdropClick)
  _ = backdrop.addEventListener!("click", JSValue.object(backdropClick))
  _ = body.appendChild!(backdrop)
  return backdrop
}
