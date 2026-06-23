import JavaScriptKit

// MARK: - Host imports (implemented in bootstrap.js via getImports)

@JSFunction func hostFetchJSON(
  _ url: String,
  _ completion: @escaping (NavContentResponse?) -> Void
) throws(JSException)

@JSFunction func hostMountModule(
  _ url: String,
  _ completion: @escaping (Bool, Int) -> Void
) throws(JSException)

@JSFunction func encodeURIComponent(_ value: String) throws(JSException) -> String

@JSFunction func decodeURIComponent(_ value: String) throws(JSException) -> String

@JSFunction func createURLSearchParams(_ search: String) throws(JSException) -> URLSearchParams

// MARK: - Globals

@JSGetter(jsName: "document", from: .global) var webDocument: Document

@JSGetter(jsName: "location", from: .global) var webLocation: Location

@JSGetter(jsName: "history", from: .global) var webHistory: History

@JSGetter(jsName: "window", from: .global) var webWindow: Window

@JSGetter(jsName: "console", from: .global) var webConsole: Console

// MARK: - DOM

@JSClass struct Document {
  @JSFunction func getElementById(_ id: String) throws(JSException) -> HTMLElement?
  @JSFunction func createElement(_ tag: String) throws(JSException) -> HTMLElement
  @JSFunction func querySelector(_ selector: String) throws(JSException) -> HTMLElement?
  @JSFunction func addEventListener(_ type: String, _ listener: @escaping (Event) -> Void) throws(JSException)
  @JSGetter var body: HTMLElement?
  @JSGetter var title: String
  @JSSetter func setTitle(_ value: String) throws(JSException)
}

@JSClass struct Window {
  @JSFunction func addEventListener(_ type: String, _ listener: @escaping (Event) -> Void) throws(JSException)
}

@JSClass struct HTMLElement {
  @JSGetter var id: String
  @JSSetter func setId(_ value: String) throws(JSException)
  @JSGetter var className: String
  @JSSetter func setClassName(_ value: String) throws(JSException)
  @JSGetter var innerHTML: String
  @JSSetter func setInnerHTML(_ value: String) throws(JSException)
  @JSGetter var textContent: String
  @JSSetter func setTextContent(_ value: String) throws(JSException)
  @JSGetter var tagName: String
  @JSGetter var href: String
  @JSSetter func setHref(_ value: String) throws(JSException)
  @JSGetter var htmlFor: String
  @JSSetter func setHtmlFor(_ value: String) throws(JSException)
  @JSGetter var hidden: Bool
  @JSSetter func setHidden(_ value: Bool) throws(JSException)
  @JSGetter var checked: Bool
  @JSSetter func setChecked(_ value: Bool) throws(JSException)
  @JSGetter var classList: DOMTokenList
  @JSGetter var dataset: JSObject
  @JSGetter var parentElement: HTMLElement?
  @JSGetter var children: HTMLCollection
  @JSFunction func appendChild(_ child: HTMLElement) throws(JSException) -> HTMLElement
  @JSFunction func replaceChildren() throws(JSException)
  @JSFunction func setAttribute(_ name: String, _ value: String) throws(JSException)
  @JSFunction func addEventListener(_ type: String, _ listener: @escaping (Event) -> Void) throws(JSException)
  @JSFunction func closest(_ selector: String) throws(JSException) -> HTMLElement?
  @JSFunction func querySelector(_ selector: String) throws(JSException) -> HTMLElement?
  @JSFunction func querySelectorAll(_ selector: String) throws(JSException) -> NodeList
  @JSFunction func contains(_ child: HTMLElement) throws(JSException) -> Bool
}

@JSClass struct DOMTokenList {
  @JSFunction func toggle(_ token: String, _ force: Bool) throws(JSException) -> Bool
  @JSFunction func contains(_ token: String) throws(JSException) -> Bool
}

@JSClass struct HTMLCollection {
  @JSGetter var length: Double
  @JSFunction func item(_ index: Double) throws(JSException) -> HTMLElement?
}

@JSClass struct NodeList {
  @JSGetter var length: Double
  @JSFunction func item(_ index: Double) throws(JSException) -> HTMLElement?
}

@JSClass struct Event {
  @JSGetter var target: HTMLElement
  @JSGetter var key: String
  @JSGetter var state: JSObject
  @JSFunction func preventDefault() throws(JSException)
}

@JSClass struct Location {
  @JSGetter var pathname: String
  @JSGetter var search: String
}

@JSClass struct History {
  @JSGetter var state: JSObject?
  @JSFunction func pushState(_ state: JSObject, _ unused: String, _ url: String) throws(JSException)
  @JSFunction func replaceState(_ state: JSObject, _ unused: String, _ url: String) throws(JSException)
}

@JSClass struct URLSearchParams {
  @JSFunction func has(_ name: String) throws(JSException) -> Bool
  @JSFunction func delete(_ name: String) throws(JSException)
  @JSFunction func get(_ name: String) throws(JSException) -> String?
  @JSFunction func toString() throws(JSException) -> String
}

@JSClass struct Console {
  @JSFunction func log(_ message: String) throws(JSException)
}
