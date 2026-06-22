import JavaScriptKit

@main
enum ShapeTreeCore {
  nonisolated(unsafe) static var listeners: [JSClosure] = []

  static func main() {
    let document = JSObject.global.document
    registerListeners(on: document)
    Router.registerHistory()
    log("listeners registered")
    Boot.run()
  }

  static func log(_ message: String) {
    _ = JSObject.global.console.log("[shape-tree-core] \(message)")
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
    syncBackdrop(in: document)
    return .undefined
  }
  ShapeTreeCore.listeners.append(changeListener)
  _ = document.addEventListener("change", JSValue.object(changeListener))

  let clickListener = JSClosure { arguments in
    guard let event = arguments[0].object,
      let target = event.target.object,
      let nav = navigationRoot(in: document)
    else {
      return .undefined
    }

    if target.closest!("a.nav-login-link").object != nil {
      _ = event.preventDefault?()
      ShapeTreeCore.log("login nav link")
      Router.showLogin(next: nil, pushState: true)
      closeAll(in: document)
      return .undefined
    }

    if let nodeLink = target.closest!("a.nav-node-link").object {
      _ = event.preventDefault?()
      let slug = wasmDataset(nodeLink, key: "slug")
      let title = wasmDataset(nodeLink, key: "title")
      let path = wasmDataset(nodeLink, key: "path")
      if let slug {
        ShapeTreeCore.log("node nav link: \(slug)")
        Router.mountNode(slug: slug, title: title, path: path, pushState: true)
      }
      closeAll(in: document)
      return .undefined
    }

    if !isContained(nav, target) {
      closeAll(in: document)
      return .undefined
    }

    if target.closest!("a.nav-link").object != nil {
      closeAll(in: document)
    }

    return .undefined
  }
  ShapeTreeCore.listeners.append(clickListener)
  _ = document.addEventListener("click", JSValue.object(clickListener))

  let keydownListener = JSClosure { arguments in
    guard let event = arguments[0].object,
      jsEquals(event.key, "Escape")
    else {
      return .undefined
    }
    closeAll(in: document)
    return .undefined
  }
  ShapeTreeCore.listeners.append(keydownListener)
  _ = document.addEventListener("keydown", JSValue.object(keydownListener))
}

func wasmDataset(_ element: JSObject, key: String) -> String? {
  guard let dataset = element.dataset.object else { return nil }
  let value = dataset[key]
  guard !value.isUndefined else { return nil }
  return value.string
}
