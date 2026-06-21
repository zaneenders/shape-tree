import JavaScriptKit

@main
enum WASMNav {
  nonisolated(unsafe) static var listeners: [JSClosure] = []

  static func main() {
    let document = JSObject.global.document
    registerListeners(on: document)
    log("listeners registered")
  }

  static func log(_ message: String) {
    _ = JSObject.global.console.log("[wasm-nav] \(message)")
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
    WASMNav.log("disclosure change")
    syncBackdrop(in: document)
    return .undefined
  }
  WASMNav.listeners.append(changeListener)
  _ = document.addEventListener("change", JSValue.object(changeListener))

  let clickListener = JSClosure { arguments in
    guard let event = arguments[0].object,
      let target = event.target.object,
      let nav = navigationRoot(in: document)
    else {
      return .undefined
    }

    if let wasmLink = target.closest!("a.nav-wasm-link").object {
      _ = event.preventDefault?()
      if let slug = wasmDataset(wasmLink, key: "wasmSlug") {
        let title = wasmDataset(wasmLink, key: "wasmTitle")
        WASMNav.log("wasm nav link: \(slug)")
        loadWasmPost(slug: slug, title: title, pushState: true)
      }
      closeAll(in: document)
      return .undefined
    }

    if !isContained(nav, target) {
      WASMNav.log("click away")
      closeAll(in: document)
      return .undefined
    }

    if target.closest!("a.nav-link").object != nil {
      WASMNav.log("nav link click")
      closeAll(in: document)
    }

    return .undefined
  }
  WASMNav.listeners.append(clickListener)
  _ = document.addEventListener("click", JSValue.object(clickListener))

  let keydownListener = JSClosure { arguments in
    guard let event = arguments[0].object,
      jsEquals(event.key, "Escape")
    else {
      return .undefined
    }
    WASMNav.log("escape")
    closeAll(in: document)
    return .undefined
  }
  WASMNav.listeners.append(keydownListener)
  _ = document.addEventListener("keydown", JSValue.object(keydownListener))

  let afterSwapListener = JSClosure { arguments in
    guard let event = arguments[0].object,
      let detail = event.detail.object,
      let swapTarget = detail.target.object,
      jsEquals(swapTarget.id, "main")
    else {
      return .undefined
    }
    WASMNav.log("htmx main swap")
    closeAll(in: document)
    return .undefined
  }
  WASMNav.listeners.append(afterSwapListener)
  _ = document.addEventListener("htmx:afterSwap", JSValue.object(afterSwapListener))

  let afterSettleListener = JSClosure { _ in
    syncBackdrop(in: document)
    return .undefined
  }
  WASMNav.listeners.append(afterSettleListener)
  _ = document.addEventListener("htmx:afterSettle", JSValue.object(afterSettleListener))
}
