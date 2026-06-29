import JavaScriptKit

public func dynamicImport(_ url: String) -> JSPromise {
  JSPromise(JSObject.global.loadESModule.function!(url).object!)!
}
