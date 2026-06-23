import JavaScriptKit

func closeAll() {
  guard let nav = navigationRoot() else {
    syncBackdrop()
    return
  }
  for checkbox in checkedDisclosures(in: nav) {
    try? checkbox.setChecked(false)
  }
  syncBackdrop()
}

func closeSiblingDisclosures(clicked: HTMLElement) {
  guard let listItem = try? clicked.closest("li"),
    let parent = try? listItem.parentElement,
    let children = try? parent.children,
    Bridge.tagName(parent) == "UL"
  else {
    return
  }

  let childCount = Bridge.collectionLength(children)
  let clickedID = Bridge.elementID(clicked)
  for index in 0..<childCount {
    guard let sibling = try? children.item(Double(index)),
      Bridge.tagName(sibling) == "LI",
      let other = try? sibling.querySelector(":scope > input.nav-disclosure")
    else {
      continue
    }
    if let clickedID, let otherID = Bridge.elementID(other), !clickedID.isEmpty, clickedID == otherID {
      continue
    }
    try? other.setChecked(false)
  }
}

func syncBackdrop() {
  guard let backdrop = ensureBackdrop() else { return }
  let nav = navigationRoot()
  let hasOpen = nav.map { !checkedDisclosures(in: $0).isEmpty } ?? false
  try? backdrop.setHidden(!hasOpen)
}
