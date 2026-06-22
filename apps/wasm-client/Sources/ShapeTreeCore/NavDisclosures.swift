import JavaScriptKit

func closeAll(in document: JSValue) {
  guard let nav = navigationRoot(in: document) else {
    syncBackdrop(in: document)
    return
  }
  for checkbox in checkedDisclosures(in: nav) {
    checkbox.checked = .boolean(false)
  }
  syncBackdrop(in: document)
}

func closeSiblingDisclosures(clicked: JSObject) {
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

func syncBackdrop(in document: JSValue) {
  guard let backdrop = ensureBackdrop(in: document) else { return }
  let nav = navigationRoot(in: document)
  let hasOpen = nav.map { !checkedDisclosures(in: $0).isEmpty } ?? false
  backdrop.hidden = .boolean(!hasOpen)
}
