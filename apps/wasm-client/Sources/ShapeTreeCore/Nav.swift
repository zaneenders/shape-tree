import JavaScriptKit

enum Nav {
  static func fetchAndRender() {
    fetchJSON("/api/get-nav-content") { payload in
      guard let payload else {
        ShapeTreeCore.log("nav fetch failed")
        return
      }
      render(payload)
    }
  }

  static func render(_ payload: JSValue) {
    guard let nav = element("styled-navigation") else { return }
    _ = nav.replaceChildren!()

    guard let list = createElement("ul") else { return }
    list.className = .string("nav-root")

    let indexPath = bodyDataset("indexPath") ?? payload.home.path.string ?? "Home"

    appendItem(to: list, item: payload.home, indexPath: indexPath)

    let signIn: JSValue = payload.signIn
    if let signInObject = signIn.object, let leaf = createElement("li") {
      leaf.className = .string("nav-leaf")
      if let link = createElement("a") {
        let spa = signInObject.spa.boolean ?? false
        link.className = .string(spa ? "nav-link nav-login-link" : "nav-link")
        link.href = signInObject.href
        setText(link, signInObject.label.string ?? "Sign in")
        _ = leaf.appendChild!(link)
      }
      _ = list.appendChild!(leaf)
    }

    let groups: JSValue = payload.groups
    let groupCount = Int(groups.object?.length.number ?? 0)
    for index in 0..<groupCount {
      appendGroup(to: list, group: groups[index], indexPath: indexPath)
    }

    _ = nav.appendChild!(list)
  }

  private static func appendItem(to list: JSObject, item: JSValue, indexPath: String) {
    guard let itemObject = item.object,
      let leaf = createElement("li"),
      let link = createElement("a")
    else { return }
    leaf.className = .string("nav-leaf")
    link.className = .string("nav-link nav-node-link")
    link.href = itemObject.href
    setText(link, itemObject.title.string ?? "")
    if let dataset = link.dataset.object {
      dataset.path = itemObject.path
      dataset.title = itemObject.title
      if let path = itemObject.path.string {
        dataset.browserPath = .string(JSString(browserPath(forItemPath: path, href: itemObject.href.string, indexPath: indexPath)))
      }
    }
    _ = leaf.appendChild!(link)
    _ = list.appendChild!(leaf)
  }

  private static func appendGroup(to list: JSObject, group: JSValue, indexPath: String) {
    guard let groupObject = group.object,
      let branch = createElement("li"),
      let input = createElement("input"),
      let label = createElement("label"),
      let flyout = createElement("ul")
    else { return }

    branch.className = .string("nav-branch")
    let directory = groupObject.directory.string ?? groupObject.label.string ?? ""
    let branchID = navBranchID(directory)

    input.type = .string("checkbox")
    input.className = .string("nav-disclosure")
    input.id = .string(JSString(branchID))

    label.className = .string("nav-branch-label")
    label.htmlFor = .string(JSString(branchID))
    setText(label, groupObject.label.string ?? "")

    flyout.className = .string("nav-flyout")
    let items: JSValue = groupObject.items
    let itemCount = Int(items.object?.length.number ?? 0)
    for index in 0..<itemCount {
      appendItem(to: flyout, item: items[index], indexPath: indexPath)
    }

    _ = branch.appendChild!(input)
    _ = branch.appendChild!(label)
    _ = branch.appendChild!(flyout)
    _ = list.appendChild!(branch)
  }

  private static func browserPath(forItemPath path: String, href: String?, indexPath: String) -> String {
    if path == indexPath { return "/" }
    if let href, !href.isEmpty { return href }
    return Router.contentBrowserPath(path: path)
  }

  private static func navBranchID(_ directory: String) -> String {
    let lowered = asciiLowercased(directory)
    let slashed = stringReplacing(lowered, "/", "-")
    return "nav-" + stringReplacing(slashed, " ", "-")
  }
}
