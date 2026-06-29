import JavaScriptKit

func fetchURL(_ url: String) -> JSPromise {
  JSPromise(JSObject.global.fetch.object!(url).object!)!
}

func postURL(_ url: String) -> JSPromise {
  let options = JSObject()
  options.method = .string("POST")
  options.redirect = .string("manual")
  return JSPromise(JSObject.global.fetch.object!(url, options).object!)!
}
