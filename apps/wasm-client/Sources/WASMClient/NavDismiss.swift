import JavaScriptKit

@main
enum NavDismiss {
  nonisolated(unsafe) static var listeners: [JSClosure] = []

  static func main() {
    let document = JSObject.global.document
    registerListeners(on: document)
    log("listeners registered")
  }

  static func log(_ message: String) {
    _ = JSObject.global.console.log("[nav] \(message)")
  }
}

private func registerListeners(on document: JSValue) {
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
    NavDismiss.log("disclosure change")
    syncBackdrop(in: document)
    return .undefined
  }
  NavDismiss.listeners.append(changeListener)
  _ = document.addEventListener("change", JSValue.object(changeListener))

  let clickListener = JSClosure { arguments in
    guard let event = arguments[0].object,
      let target = event.target.object,
      let nav = navigationRoot(in: document)
    else {
      return .undefined
    }

    if !isContained(nav, target) {
      NavDismiss.log("click away")
      closeAll(in: document)
      return .undefined
    }

    if target.closest!("a.nav-link").object != nil {
      NavDismiss.log("nav link click")
      closeAll(in: document)
    }

    return .undefined
  }
  NavDismiss.listeners.append(clickListener)
  _ = document.addEventListener("click", JSValue.object(clickListener))

  let keydownListener = JSClosure { arguments in
    guard let event = arguments[0].object,
      jsEquals(event.key, "Escape")
    else {
      return .undefined
    }
    NavDismiss.log("escape")
    closeAll(in: document)
    return .undefined
  }
  NavDismiss.listeners.append(keydownListener)
  _ = document.addEventListener("keydown", JSValue.object(keydownListener))

  let afterSwapListener = JSClosure { arguments in
    guard let event = arguments[0].object,
      let detail = event.detail.object,
      let swapTarget = detail.target.object,
      jsEquals(swapTarget.id, "main")
    else {
      return .undefined
    }
    NavDismiss.log("htmx main swap")
    closeAll(in: document)
    return .undefined
  }
  NavDismiss.listeners.append(afterSwapListener)
  _ = document.addEventListener("htmx:afterSwap", JSValue.object(afterSwapListener))

  let afterSettleListener = JSClosure { _ in
    syncBackdrop(in: document)
    return .undefined
  }
  NavDismiss.listeners.append(afterSettleListener)
  _ = document.addEventListener("htmx:afterSettle", JSValue.object(afterSettleListener))
}
