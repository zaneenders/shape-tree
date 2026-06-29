import JavaScriptEventLoop
import JavaScriptKit
import ShapeTreeDOM

public enum FetchError: Error {
  case failed
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
