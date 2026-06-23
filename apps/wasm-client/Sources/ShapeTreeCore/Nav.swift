import JavaScriptKit

enum Nav {
  static func fetchAndRender() {
    fetchJSON("/api/get-nav-content") { payload in
      guard let payload else {
        Bridge.log("nav fetch failed")
        return
      }
      render(payload)
    }
  }

  static func render(_ payload: JSObject) {
    guard let nav = element("styled-navigation") else { return }
    try? nav.replaceChildren()

    guard let list = createElement("ul") else { return }
    try? list.setClassName("nav-root")

    let indexPath = bodyDataset("indexPath")
      ?? (payload["home"].object.flatMap { Bridge.jsObjectPropertyString($0, "path") })
      ?? "Home"

    if let home = payload["home"].object {
      appendItem(to: list, item: home, indexPath: indexPath)
    }

    if let signInObject = payload["signIn"].object, let leaf = createElement("li") {
      try? leaf.setClassName("nav-leaf")
      if let link = createElement("a") {
        let spa = Bridge.jsObjectPropertyBool(signInObject, "spa") ?? false
        try? link.setClassName(spa ? "nav-link nav-login-link" : "nav-link")
        if let href = Bridge.jsObjectPropertyString(signInObject, "href") {
          try? link.setHref(href)
        }
        try? link.setTextContent(Bridge.jsObjectPropertyString(signInObject, "label") ?? "Sign in")
        _ = try? leaf.appendChild(link)
      }
      _ = try? list.appendChild(leaf)
    }

    let groups = payload["groups"]
    let groupCount = Bridge.jsArrayLength(groups)
    for index in 0..<groupCount {
      let group = Bridge.jsArrayElement(groups, index)
      if let groupObject = group.object {
        appendGroup(to: list, group: groupObject, indexPath: indexPath)
      }
    }

    _ = try? nav.appendChild(list)
  }

  private static func appendItem(to list: HTMLElement, item: JSObject, indexPath: String) {
    guard let leaf = createElement("li"), let link = createElement("a") else { return }
    try? leaf.setClassName("nav-leaf")
    try? link.setClassName("nav-link nav-node-link")
    if let href = Bridge.jsObjectPropertyString(item, "href") {
      try? link.setHref(href)
    }
    try? link.setTextContent(Bridge.jsObjectPropertyString(item, "title") ?? "")
    if let dataset = Bridge.elementDataset(link) {
      if let path = Bridge.jsObjectPropertyString(item, "path") {
        Bridge.setDataset(dataset, "path", .string(path))
        Bridge.setDataset(
          dataset,
          "browserPath",
          .string(browserPath(forItemPath: path, href: Bridge.jsObjectPropertyString(item, "href"), indexPath: indexPath))
        )
      }
      if let title = Bridge.jsObjectPropertyString(item, "title") {
        Bridge.setDataset(dataset, "title", .string(title))
      }
    }
    _ = try? leaf.appendChild(link)
    _ = try? list.appendChild(leaf)
  }

  private static func appendGroup(to list: HTMLElement, group: JSObject, indexPath: String) {
    guard let branch = createElement("li"),
      let input = createElement("input"),
      let label = createElement("label"),
      let flyout = createElement("ul")
    else { return }

    try? branch.setClassName("nav-branch")
    let directory = Bridge.jsObjectPropertyString(group, "directory")
      ?? Bridge.jsObjectPropertyString(group, "label") ?? ""
    let branchID = navBranchID(directory)

    try? input.setAttribute("type", "checkbox")
    try? input.setClassName("nav-disclosure")
    try? input.setId(branchID)

    try? label.setClassName("nav-branch-label")
    try? label.setHtmlFor(branchID)
    try? label.setTextContent(Bridge.jsObjectPropertyString(group, "label") ?? "")

    try? flyout.setClassName("nav-flyout")
    let items = group["items"]
    let itemCount = Bridge.jsArrayLength(items)
    for index in 0..<itemCount {
      let item = Bridge.jsArrayElement(items, index)
      if let itemObject = item.object {
        appendItem(to: flyout, item: itemObject, indexPath: indexPath)
      }
    }

    _ = try? branch.appendChild(input)
    _ = try? branch.appendChild(label)
    _ = try? branch.appendChild(flyout)
    _ = try? list.appendChild(branch)
  }

  private static func browserPath(forItemPath path: String, href: String?, indexPath: String) -> String {
    if path == indexPath { return "/" }
    if let href, !href.isEmpty { return href }
    return Router.contentBrowserPath(path: path)
  }

  private static func navBranchID(_ directory: String) -> String {
    let lowered = directory.lowercased()
    let slashed = stringReplacing(lowered, "/", "-")
    return "nav-" + stringReplacing(slashed, " ", "-")
  }
}
