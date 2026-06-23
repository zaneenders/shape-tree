import JavaScriptKit

/// `fetch(url, { credentials: "include" })` decoded as JSON, or nil on any failure.
/// Embedded Swift has no concurrency runtime, so this is promise/callback based.
func fetchJSON(_ url: String, completion: @escaping (JSValue?) -> Void) {
  guard let fetchFn = JSObject.global.fetch.function,
    let promise = JSPromise(from: fetchFn(url, fetchOptions()))
  else {
    completion(nil)
    return
  }
  _ = promise.then(
    success: { response in
      guard let responseObject = response.object, response.ok.boolean == true,
        let jsonPromise = JSPromise(from: responseObject.json!())
      else {
        completion(nil)
        return JSValue.undefined
      }
      _ = jsonPromise.then(
        success: { json in
          completion(json)
          return JSValue.undefined
        },
        failure: { _ in
          completion(nil)
          return JSValue.undefined
        })
      return JSValue.undefined
    },
    failure: { _ in
      completion(nil)
      return JSValue.undefined
    })
}

private func fetchOptions() -> JSObject {
  let options = JSObject()
  options.credentials = .string("include")
  return options
}

struct MountResult {
  var ok: Bool
  var status: Int
}

/// Asks the JS loader to fetch and instantiate a node wasm into `#main`.
func mountModule(_ url: String, completion: @escaping (MountResult) -> Void) {
  guard let shapeTree = JSObject.global.shapeTree.object,
    shapeTree.mount.function != nil,
    let promise = JSPromise(from: shapeTree.mount!(url))
  else {
    ShapeTreeCore.log("shapeTree.mount unavailable")
    completion(MountResult(ok: false, status: 0))
    return
  }
  _ = promise.then(
    success: { resolved in
      completion(
        MountResult(
          ok: resolved.ok.boolean ?? false,
          status: Int(resolved.status.number ?? 0)
        ))
      return JSValue.undefined
    },
    failure: { _ in
      completion(MountResult(ok: false, status: 0))
      return JSValue.undefined
    })
}

// MARK: - Document helpers

var document: JSValue { JSObject.global.document }

func element(_ id: String) -> JSObject? {
  document.getElementById(id).object
}

func createElement(_ tag: String) -> JSObject? {
  document.createElement(tag).object
}

func bodyDataset(_ key: String) -> String? {
  guard let body = document.body.object, let dataset = body.dataset.object else { return nil }
  let value = dataset[key]
  guard !value.isUndefined else { return nil }
  return value.string
}

func bodyFlag(_ key: String) -> Bool {
  guard let body = document.body.object, let dataset = body.dataset.object else { return false }
  return jsEquals(dataset[key], "true")
}

func setText(_ object: JSObject, _ text: String) {
  object.textContent = .string(text)
}

func setHTML(_ object: JSObject, _ html: String) {
  object.innerHTML = .string(html)
}

func setLoading(_ active: Bool) {
  if let indicator = element("site-loading")?.classList.object {
    _ = indicator.toggle!("is-loading", active)
  }
  if let main = element("main")?.classList.object {
    _ = main.toggle!("is-loading", active)
  }
}

func siteTitle() -> String {
  guard let titleEl = document.querySelector("title").object,
    let dataset = titleEl.dataset.object
  else { return "" }
  return dataset.siteTitle.string ?? ""
}

func setDocumentTitle(_ pageTitle: String?) {
  let site = siteTitle()
  if let pageTitle, !pageTitle.isEmpty {
    document.title = .string("\(pageTitle) · \(site)")
  } else {
    document.title = .string(site)
  }
}

// MARK: - Location & history

func locationPathname() -> String {
  JSObject.global.location.pathname.string ?? "/"
}

func locationSearch() -> String {
  JSObject.global.location.search.string ?? ""
}

func locationIsRoot() -> Bool {
  let path = locationPathname()
  return path == "/" || path.isEmpty
}

func pushHistory(state: JSObject, path: String) {
  _ = JSObject.global.history.object?.pushState!(state, "", path)
}

func replaceHistory(state: JSObject, path: String) {
  _ = JSObject.global.history.object?.replaceState!(state, "", path)
}

func encodeURIComponent(_ value: String) -> String {
  JSObject.global.encodeURIComponent!(value).string ?? value
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
