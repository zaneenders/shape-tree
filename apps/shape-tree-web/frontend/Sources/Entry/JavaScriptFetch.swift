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

func postFormURL(_ url: String, body: String) -> JSPromise {
  let options = JSObject()
  options.method = .string("POST")
  options.redirect = .string("manual")
  options.credentials = .string("same-origin")
  let headers = JSObject()
  headers["Content-Type"] = .string("application/x-www-form-urlencoded")
  options.headers = .object(headers)
  options.body = .string(body)
  return JSPromise(JSObject.global.fetch.object!(url, options).object!)!
}
