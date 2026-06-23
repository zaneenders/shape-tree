import JavaScriptKit

struct MountResult {
  var ok: Bool
  var status: Int
}

func fetchJSON(_ url: String, completion: @escaping (JSObject?) -> Void) {
  try? hostFetchJSON(url, completion)
}

func mountModule(_ url: String, completion: @escaping (MountResult) -> Void) {
  try? hostMountModule(url) { ok, status in
    completion(MountResult(ok: ok, status: status))
  }
}

func element(_ id: String) -> HTMLElement? {
  try? webDocument.getElementById(id)
}

func createElement(_ tag: String) -> HTMLElement? {
  try? webDocument.createElement(tag)
}

func bodyDataset(_ key: String) -> String? {
  guard let body = try? webDocument.body else { return nil }
  return Bridge.datasetString(body, key)
}

func setText(_ object: HTMLElement, _ text: String) {
  try? object.setTextContent(text)
}

func setHTML(_ object: HTMLElement, _ html: String) {
  try? object.setInnerHTML(html)
}

func setLoading(_ active: Bool) {
  if let el = try? webDocument.getElementById("site-loading") {
    _ = try? el.classList.toggle("is-loading", active)
  }
  if let main = try? webDocument.getElementById("main") {
    _ = try? main.classList.toggle("is-loading", active)
  }
}

func siteTitle() -> String {
  guard let titleEl = try? webDocument.querySelector("title") else { return "" }
  return Bridge.datasetString(titleEl, "siteTitle") ?? ""
}

func setDocumentTitle(_ pageTitle: String?) {
  let site = siteTitle()
  if let pageTitle, !pageTitle.isEmpty {
    try? webDocument.setTitle("\(pageTitle) · \(site)")
  } else {
    try? webDocument.setTitle(site)
  }
}

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

func pushHistory(state: JSObject, path: String) {
  try? webHistory.pushState(state, "", path)
}

func replaceHistory(state: JSObject, path: String) {
  try? webHistory.replaceState(state, "", path)
}

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
