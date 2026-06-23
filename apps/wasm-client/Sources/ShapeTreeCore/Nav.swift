import JavaScriptKit

enum Nav {
  static func fetchAndRender() {
    fetchNavContent("/api/get-nav-content") { payload in
      guard let payload else {
        log("nav fetch failed")
        return
      }
      render(payload)
    }
  }

  static func render(_ payload: NavContentResponse) {
    guard let nav = element("styled-navigation") else { return }
    try? nav.replaceChildren()

    guard let list = createElement("ul") else { return }
    try? list.setClassName("nav-root")

    let indexPath = bodyDataset("indexPath") ?? payload.home.path

    appendItem(to: list, item: payload.home, indexPath: indexPath)

    if let signIn = payload.signIn, let leaf = createElement("li") {
      try? leaf.setClassName("nav-leaf")
      if let link = createElement("a") {
        try? link.setClassName(signIn.spa ? "nav-link nav-login-link" : "nav-link")
        try? link.setHref(signIn.href)
        try? link.setTextContent(signIn.label)
        _ = try? leaf.appendChild(link)
      }
      _ = try? list.appendChild(leaf)
    }

    for group in payload.groups {
      appendGroup(to: list, group: group, indexPath: indexPath)
    }

    _ = try? nav.appendChild(list)
  }

  private static func appendItem(to list: HTMLElement, item: NavContentItem, indexPath: String) {
    guard let leaf = createElement("li"), let link = createElement("a") else { return }
    try? leaf.setClassName("nav-leaf")
    try? link.setClassName("nav-link nav-node-link")
    try? link.setHref(item.href)
    try? link.setTextContent(item.title)
    if let dataset = try? link.dataset {
      setDataset(dataset, key: "path", value: item.path)
      setDataset(
        dataset,
        key: "browserPath",
        value: browserPath(forItemPath: item.path, href: item.href, indexPath: indexPath)
      )
      setDataset(dataset, key: "title", value: item.title)
    }
    _ = try? leaf.appendChild(link)
    _ = try? list.appendChild(leaf)
  }

  private static func appendGroup(to list: HTMLElement, group: NavContentGroup, indexPath: String) {
    guard let branch = createElement("li"),
      let input = createElement("input"),
      let label = createElement("label"),
      let flyout = createElement("ul")
    else { return }

    try? branch.setClassName("nav-branch")
    let directory = group.directory ?? group.label
    let branchID = navBranchID(directory)

    try? input.setAttribute("type", "checkbox")
    try? input.setClassName("nav-disclosure")
    try? input.setId(branchID)

    try? label.setClassName("nav-branch-label")
    try? label.setHtmlFor(branchID)
    try? label.setTextContent(group.label)

    try? flyout.setClassName("nav-flyout")
    for item in group.items {
      appendItem(to: flyout, item: item, indexPath: indexPath)
    }

    _ = try? branch.appendChild(input)
    _ = try? branch.appendChild(label)
    _ = try? branch.appendChild(flyout)
    _ = try? list.appendChild(branch)
  }

  private static func browserPath(forItemPath path: String, href: String, indexPath: String) -> String {
    if path == indexPath { return "/" }
    if !href.isEmpty { return href }
    return Router.contentBrowserPath(path: path)
  }

  private static func navBranchID(_ directory: String) -> String {
    let lowered = directory.lowercased()
    let slashed = stringReplacing(lowered, "/", "-")
    return "nav-" + stringReplacing(slashed, " ", "-")
  }
}
