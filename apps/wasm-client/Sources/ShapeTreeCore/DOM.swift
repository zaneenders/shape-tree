import HTML
import JavaScriptKit
import ShapeTreeKit

struct MountResult {
  var ok: Bool
  var status: Int
}

// MARK: - Host

func fetchNavContent(_ url: String, completion: @escaping (NavContentResponse?) -> Void) {
  try? hostFetchJSON(url) { object in
    guard let object else {
      completion(nil)
      return
    }
    completion(NavContentResponse(unsafelyCopying: object))
  }
}

func mountModule(_ url: String, completion: @escaping (MountResult) -> Void) {
  try? hostMountModule(url) { ok, status in
    completion(MountResult(ok: ok, status: status))
  }
}

func log(_ message: String) {
  try? webConsole.log("[shape-tree-core] \(message)")
}

// MARK: - Elements

func element(_ id: String) -> HTMLElement? {
  try? webDocument.getElementById(id)
}

func createElement(_ tag: String) -> HTMLElement? {
  try? webDocument.createElement(tag)
}

func hasClass(_ element: HTMLElement, _ className: String) -> Bool {
  (try? element.classList.contains(className)) == true
}

func isContained(_ parent: HTMLElement, _ child: HTMLElement) -> Bool {
  (try? parent.contains(child)) == true
}

func navigationRoot() -> HTMLElement? {
  element("styled-navigation")
}

func checkedDisclosures(in nav: HTMLElement) -> [HTMLElement] {
  guard let nodeList = try? nav.querySelectorAll("input.nav-disclosure[type=\"checkbox\"]:checked") else {
    return []
  }
  let length = Int((try? nodeList.length) ?? 0)
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
  if let existing = element("nav-backdrop") {
    return existing
  }
  guard let body = try? webDocument.body,
    let backdrop = createElement("div")
  else { return nil }
  try? backdrop.setId("nav-backdrop")
  try? backdrop.setAttribute("aria-hidden", "true")
  try? backdrop.addEventListener("click") { _ in
    log("backdrop click")
    closeAll()
  }
  _ = try? body.appendChild(backdrop)
  return backdrop
}

// MARK: - Dataset

func bodyDataset(_ key: String) -> String? {
  guard let body = try? webDocument.body else { return nil }
  return datasetString(body, key: key)
}

func datasetString(_ element: HTMLElement, key: String) -> String? {
  guard let dataset = try? element.dataset else { return nil }
  return datasetString(dataset, key: key)
}

func datasetString(_ dataset: JSObject, key: String) -> String? {
  let value = dataset[key]
  guard !value.isUndefined, !value.isNull else { return nil }
  return value.string
}

func setDataset(_ dataset: JSObject, key: String, value: String) {
  dataset[key] = .string(value)
}

// MARK: - Content

func setText(_ object: HTMLElement, _ text: String) {
  try? object.setTextContent(text)
}

func setHTML(_ object: HTMLElement, _ html: HTML) {
  setHTML(object, html.render())
}

func setHTML(_ object: HTMLElement, _ html: String) {
  try? object.setInnerHTML(html)
}

func setLoading(_ active: Bool) {
  if let el = element("site-loading") {
    _ = try? el.classList.toggle("is-loading", active)
  }
  if let main = element("main") {
    _ = try? main.classList.toggle("is-loading", active)
  }
}

func siteTitle() -> String {
  guard let titleEl = try? webDocument.querySelector("title") else { return "" }
  return datasetString(titleEl, key: "siteTitle") ?? ""
}

func setDocumentTitle(_ pageTitle: String?) {
  let site = siteTitle()
  if let pageTitle, !pageTitle.isEmpty {
    try? webDocument.setTitle("\(pageTitle) · \(site)")
  } else {
    try? webDocument.setTitle(site)
  }
}

// MARK: - Location & history

func locationPathname() -> String {
  (try? webLocation.pathname) ?? "/"
}

func locationSearch() -> String {
  (try? webLocation.search) ?? ""
}

func locationIsRoot() -> Bool {
  let path = locationPathname()
  return path == "/" || path.isEmpty
}

func pushHistory(state: HistoryState, path: String) {
  try? webHistory.pushState(state.toJSObject(), "", path)
}

func replaceHistory(state: HistoryState, path: String) {
  try? webHistory.replaceState(state.toJSObject(), "", path)
}

func currentHistoryState() -> HistoryState {
  guard let state = try? webHistory.state else { return HistoryState() }
  return HistoryState(unsafelyCopying: state)
}

func historyState(from event: Event) -> HistoryState? {
  guard let state = try? event.state else { return nil }
  return HistoryState(unsafelyCopying: state)
}

// MARK: - Encoding & escaping

func encodedPathComponent(_ value: String) -> String {
  (try? encodeURIComponent(value)) ?? value
}

func escapeHTML(_ value: String) -> String {
  var result = stringReplacing(value, "&", "&amp;")
  result = stringReplacing(result, "<", "&lt;")
  return stringReplacing(result, ">", "&gt;")
}

func escapeAttr(_ value: String) -> String {
  let result = stringReplacing(value, "&", "&amp;")
  return stringReplacing(result, "\"", "&quot;")
}

// MARK: - Query params

func readQueryParam(_ name: String) -> String? {
  let search = locationSearch()
  guard let params = try? createURLSearchParams(search) else { return nil }
  return try? params.get(name)
}

func nonEmpty(_ value: String?) -> String? {
  guard let value, !value.isEmpty else { return nil }
  return value
}
