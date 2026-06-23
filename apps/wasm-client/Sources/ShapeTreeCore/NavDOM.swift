import JavaScriptKit

func hasClass(_ element: HTMLElement, _ className: String) -> Bool {
  (try? element.classList.contains(className)) == true
}

func isContained(_ parent: HTMLElement, _ child: HTMLElement) -> Bool {
  (try? parent.contains(child)) == true
}

func navigationRoot() -> HTMLElement? {
  try? webDocument.getElementById("styled-navigation")
}

func checkedDisclosures(in nav: HTMLElement) -> [HTMLElement] {
  guard let nodeList = try? nav.querySelectorAll("input.nav-disclosure[type=\"checkbox\"]:checked") else {
    return []
  }
  let length = Bridge.nodeListLength(nodeList)
  var values: [HTMLElement] = []
  values.reserveCapacity(length)
  for index in 0..<length {
    if let value = try? nodeList.item(Double(index)) {
      values.append(value)
    }
  }
  return values
}

func ensureBackdrop() -> HTMLElement? {
  if let existing = try? webDocument.getElementById("nav-backdrop") {
    return existing
  }
  guard let body = try? webDocument.body,
    let backdrop = try? webDocument.createElement("div")
  else { return nil }
  try? backdrop.setId("nav-backdrop")
  try? backdrop.setAttribute("aria-hidden", "true")
  try? backdrop.addEventListener("click") { _ in
    Bridge.log("backdrop click")
    closeAll()
  }
  _ = try? body.appendChild(backdrop)
  return backdrop
}
