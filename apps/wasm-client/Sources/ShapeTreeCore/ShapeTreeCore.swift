import JavaScriptKit

@main
enum ShapeTreeCore {
  static func main() {
    registerListeners()
    Router.registerHistory()
    Bridge.log("listeners registered")
    Boot.run()
  }
}

private func registerListeners() {
  try? webDocument.addEventListener("change") { event in
    guard let target = Bridge.eventTarget(event),
      hasClass(target, "nav-disclosure"),
      let nav = navigationRoot()
    else {
      return
    }
    guard isContained(nav, target) else { return }
    if Bridge.isChecked(target) {
      closeSiblingDisclosures(clicked: target)
    }
    syncBackdrop()
  }

  try? webDocument.addEventListener("click") { event in
    guard let target = Bridge.eventTarget(event),
      let nav = navigationRoot()
    else { return }

    if let _ = try? target.closest("a.nav-login-link") {
      try? event.preventDefault()
      Bridge.log("login nav link")
      Router.showLogin(next: nil, pushState: true)
      closeAll()
      return
    }

    if let nodeLink = try? target.closest("a.nav-node-link") {
      try? event.preventDefault()
      let path = wasmDataset(nodeLink, key: "path")
      let title = wasmDataset(nodeLink, key: "title")
      let browserPath = wasmDataset(nodeLink, key: "browserPath")
      if let path {
        Bridge.log("node nav link: \(path)")
        Router.mountContent(path: path, title: title, browserPath: browserPath, pushState: true)
      }
      closeAll()
      return
    }

    if !isContained(nav, target) {
      closeAll()
      return
    }

    if let _ = try? target.closest("a.nav-link") {
      closeAll()
    }
  }

  try? webDocument.addEventListener("keydown") { event in
    guard Bridge.eventKey(event) == "Escape" else { return }
    closeAll()
  }
}

func wasmDataset(_ element: HTMLElement, key: String) -> String? {
  Bridge.datasetString(element, key)
}
