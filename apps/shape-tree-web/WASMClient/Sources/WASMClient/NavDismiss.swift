import JavaScriptKit

@main
enum NavDismiss {
  private nonisolated(unsafe) static var listeners: [JSClosure] = []

  static func main() {
    let document = JSObject.global.document
    registerListeners(on: document)
    log("listeners registered")
  }

  private static func log(_ message: String) {
    _ = JSObject.global.console.log("[nav] \(message)")
  }

  private static func registerListeners(on document: JSValue) {
    let changeListener = JSClosure { arguments in
      guard let event = arguments[0].object,
        let target = event.target.object,
        jsEquals(target.type, "checkbox"),
        hasClass(target, "nav-disclosure"),
        let nav = navigationRoot(in: document),
        isContained(nav, target)
      else {
        return .undefined
      }
      if target.checked.boolean == true {
        closeSiblingDisclosures(clicked: target)
      }
      log("disclosure change")
      syncBackdrop(in: document)
      return .undefined
    }
    listeners.append(changeListener)
    _ = document.addEventListener("change", JSValue.object(changeListener))

    let clickListener = JSClosure { arguments in
      guard let event = arguments[0].object,
        let target = event.target.object,
        let nav = navigationRoot(in: document)
      else {
        return .undefined
      }

      if !isContained(nav, target) {
        log("click away")
        closeAll(in: document)
        return .undefined
      }

      if target.closest!("a.nav-link").object != nil {
        log("nav link click")
        closeAll(in: document)
      }

      return .undefined
    }
    listeners.append(clickListener)
    _ = document.addEventListener("click", JSValue.object(clickListener))

    let keydownListener = JSClosure { arguments in
      guard let event = arguments[0].object,
        jsEquals(event.key, "Escape")
      else {
        return .undefined
      }
      log("escape")
      closeAll(in: document)
      return .undefined
    }
    listeners.append(keydownListener)
    _ = document.addEventListener("keydown", JSValue.object(keydownListener))

    let afterSwapListener = JSClosure { arguments in
      guard let event = arguments[0].object,
        let detail = event.detail.object,
        let swapTarget = detail.target.object,
        jsEquals(swapTarget.id, "main")
      else {
        return .undefined
      }
      log("htmx main swap")
      closeAll(in: document)
      return .undefined
    }
    listeners.append(afterSwapListener)
    _ = document.addEventListener("htmx:afterSwap", JSValue.object(afterSwapListener))

    let afterSettleListener = JSClosure { _ in
      syncBackdrop(in: document)
      return .undefined
    }
    listeners.append(afterSettleListener)
    _ = document.addEventListener("htmx:afterSettle", JSValue.object(afterSettleListener))
  }

  private static func jsEquals(_ lhs: JSValue, _ rhs: JSString) -> Bool {
    guard let left = lhs.jsString else { return false }
    return left == rhs
  }

  private static func jsEquals(_ lhs: JSValue, _ rhs: String) -> Bool {
    jsEquals(lhs, JSString(rhs))
  }

  private static func hasClass(_ element: JSObject, _ className: String) -> Bool {
    guard let classList = element.classList.object else { return false }
    return classList.contains!(className).boolean == true
  }

  private static func isContained(_ parent: JSObject, _ child: JSObject) -> Bool {
    parent.contains!(child).boolean == true
  }

  private static func navigationRoot(in document: JSValue) -> JSObject? {
    document.getElementById("styled-navigation").object
  }

  private static func ensureBackdrop(in document: JSValue) -> JSObject? {
    if let existing = document.getElementById("nav-backdrop").object {
      return existing
    }
    guard let body = document.body.object else { return nil }
    guard let backdrop = document.createElement("div").object else { return nil }
    backdrop.id = .string("nav-backdrop")
    _ = backdrop.setAttribute!("aria-hidden", "true")
    let backdropClick = JSClosure { _ in
      log("backdrop click")
      closeAll(in: document)
      return .undefined
    }
    listeners.append(backdropClick)
    _ = backdrop.addEventListener!("click", JSValue.object(backdropClick))
    _ = body.appendChild!(backdrop)
    return backdrop
  }

  private static func syncBackdrop(in document: JSValue) {
    guard let backdrop = ensureBackdrop(in: document) else { return }
    let nav = navigationRoot(in: document)
    let hasOpen = nav.map { !checkedDisclosures(in: $0).isEmpty } ?? false
    backdrop.hidden = .boolean(!hasOpen)
  }

  private static func closeAll(in document: JSValue) {
    guard let nav = navigationRoot(in: document) else {
      syncBackdrop(in: document)
      return
    }
    for checkbox in checkedDisclosures(in: nav) {
      checkbox.checked = .boolean(false)
    }
    syncBackdrop(in: document)
  }

  private static func closeSiblingDisclosures(clicked: JSObject) {
    guard let listItem = clicked.closest!("li").object,
      let parent = listItem.parentElement.object,
      jsEquals(parent.tagName, "UL")
    else {
      return
    }

    let childCount = Int(parent.children.length.number ?? 0)
    for index in 0..<childCount {
      guard let sibling = parent.children.item(Double(index)).object,
        sibling != listItem,
        jsEquals(sibling.tagName, "LI"),
        let other = sibling.querySelector!(":scope > input.nav-disclosure").object,
        other != clicked
      else {
        continue
      }
      other.checked = .boolean(false)
    }
  }

  private static func checkedDisclosures(in nav: JSObject) -> [JSObject] {
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
}
