import JavaScriptKit

// MARK: - Page → shell

@JSFunction func hostPostToShell(_ message: PageMessage) throws(JSException)

// MARK: - Minimal DOM for content pages

@JSGetter(jsName: "document", from: .global) var pageDocument: PageDocument

@JSGetter(jsName: "console", from: .global) var pageConsole: PageConsole

@JSClass struct PageDocument {
  @JSFunction func getElementById(_ id: String) throws(JSException) -> PageHTMLElement?
}

@JSClass struct PageHTMLElement {
  @JSSetter func setInnerHTML(_ value: String) throws(JSException)
}

@JSClass struct PageConsole {
  @JSFunction func log(_ message: String) throws(JSException)
}
