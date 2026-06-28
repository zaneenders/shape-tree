import JavaScriptEventLoop
import JavaScriptKit

public enum FetchError: Error {
  case failed
}

public func fetchURL(_ url: String) -> JSPromise {
  JSPromise(JSObject.global.fetch.object!(url).object!)!
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

public func fetchText(_ url: String) async throws(FetchError) -> String {
  let bytes = try await fetchBytes(url)
  return String(decoding: bytes, as: UTF8.self)
}
