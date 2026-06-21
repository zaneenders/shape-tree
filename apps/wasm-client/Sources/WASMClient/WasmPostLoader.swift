import JavaScriptKit

func wasmDataset(_ element: JSObject, key: String) -> String? {
  guard let dataset = element.dataset.object else { return nil }
  let value = dataset[key]
  guard !value.isUndefined else { return nil }
  return value.string
}

func loadWasmPost(slug: String, title: String?, pushState: Bool) {
  guard let shapeTree = JSObject.global.shapeTree.object else {
    WASMNav.log("shapeTree.loadWasmPost unavailable")
    return
  }

  let options = JSObject()
  options.pushState = .boolean(pushState)
  if let title {
    options.title = .string(JSString(title))
  }
  _ = shapeTree.loadWasmPost!(
    JSValue.string(JSString(slug)),
    JSValue.object(options)
  )
}
