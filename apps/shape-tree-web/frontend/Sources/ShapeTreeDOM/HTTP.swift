import JavaScriptEventLoop
import JavaScriptKit

public enum FetchError: Error {
  case failed
}

public func fetchURL(_ url: String) -> JSPromise {
  JSPromise(JSObject.global.fetch.object!(url).object!)!
}

public func postURL(_ url: String) -> JSPromise {
  let options = JSObject()
  options.method = .string("POST")
  options.redirect = .string("manual")
  return JSPromise(JSObject.global.fetch.object!(url, options).object!)!
}

public func postFormURL(_ url: String, body: String) -> JSPromise {
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

public func responseJSON(_ response: JSValue) -> JSPromise {
  JSPromise(response.json().object!)!
}

public func fetchResponseJSON(_ url: String) async throws(FetchError) -> JSValue {
  let response: JSValue
  do {
    response = try await fetchURL(url).value
  } catch {
    throw FetchError.failed
  }

  do {
    return try await responseJSON(response).value
  } catch {
    throw FetchError.failed
  }
}

public func bytesFromUint8Array(_ array: JSValue) -> [UInt8] {
  let uint8Array = array.object!
  let length = Int(uint8Array.length.number!)
  var bytes = [UInt8]()
  bytes.reserveCapacity(length)
  for index in 0..<length {
    bytes.append(UInt8(uint8Array[index].number!))
  }
  return bytes
}

public func fetchBytes(_ url: String) async throws(FetchError) -> [UInt8] {
  let response: JSValue
  do {
    response = try await fetchURL(url).value
  } catch {
    throw FetchError.failed
  }

  let arrayBuffer: JSValue
  do {
    arrayBuffer = try await JSPromise(response.arrayBuffer().object!)!.value
  } catch {
    throw FetchError.failed
  }

  let uint8Array = JSObject.global.Uint8Array.function!.new(arrayBuffer)
  return bytesFromUint8Array(.object(uint8Array))
}
