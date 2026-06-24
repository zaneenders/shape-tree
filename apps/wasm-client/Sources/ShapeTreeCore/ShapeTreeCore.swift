import JavaScriptKit

@main
enum ShapeTreeCore {
  static func main() {
    registerListeners()
    Router.registerHistory()
    log("listeners registered")
    Boot.run()
  }
}

private func registerListeners() {
  try? webDocument.addEventListener("change") { event in
    guard let target = try? event.target,
      hasClass(target, "nav-disclosure"),
      let nav = navigationRoot()
    else {
      return
    }
    guard isContained(nav, target) else { return }
    if (try? target.checked) == true {
      closeSiblingDisclosures(clicked: target)
    }
    syncBackdrop()
  }

  try? webDocument.addEventListener("click") { event in
    guard let target = try? event.target,
      let nav = navigationRoot()
    else { return }

    if let _ = try? target.closest("a.nav-login-link") {
      try? event.preventDefault()
      log("login nav link")
      Router.showLogin(next: nil, pushState: true)
      closeAll()
      return
    }

    if let nodeLink = try? target.closest("a.nav-node-link") {
      try? event.preventDefault()
      let path = datasetString(nodeLink, key: "path")
      let title = datasetString(nodeLink, key: "title")
      let browserPath = datasetString(nodeLink, key: "browserPath")
      if let path {
        log("node nav link: \(path)")
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
    guard (try? event.key) == "Escape" else { return }
    closeAll()
  }
}
