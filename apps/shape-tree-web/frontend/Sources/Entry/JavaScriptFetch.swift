import JavaScriptKit

func fetchURL(_ url: String) -> JSPromise {
  JSPromise(JSObject.global.fetch.object!(url).object!)!
}
