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

    let homeSlug = bodyDataset("homeSlug") ?? payload.home.slug.string

    appendItem(to: list, item: payload.home, homeSlug: homeSlug)

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
      appendGroup(to: list, group: groups[index], homeSlug: homeSlug)
    }

    _ = nav.appendChild!(list)
  }

  private static func appendItem(to list: JSObject, item: JSValue, homeSlug: String?) {
    guard let itemObject = item.object,
      let leaf = createElement("li"),
      let link = createElement("a")
    else { return }
    leaf.className = .string("nav-leaf")
    link.className = .string("nav-link nav-node-link")
    link.href = itemObject.href
    setText(link, itemObject.title.string ?? "")
    if let dataset = link.dataset.object {
      dataset.slug = itemObject.slug
      dataset.title = itemObject.title
      if let homeSlug, jsEquals(itemObject.slug, homeSlug) {
        dataset.path = .string("/")
      }
    }
    _ = leaf.appendChild!(link)
    _ = list.appendChild!(leaf)
  }

  private static func appendGroup(to list: JSObject, group: JSValue, homeSlug: String?) {
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
      appendItem(to: flyout, item: items[index], homeSlug: homeSlug)
    }

    _ = branch.appendChild!(input)
    _ = branch.appendChild!(label)
    _ = branch.appendChild!(flyout)
    _ = list.appendChild!(branch)
  }

  private static func navBranchID(_ directory: String) -> String {
    let lowered = asciiLowercased(directory)
    let slashed = stringReplacing(lowered, "/", "-")
    return "nav-" + stringReplacing(slashed, " ", "-")
  }
}
