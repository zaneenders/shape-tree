import JavaScriptEventLoop
import JavaScriptKit

func bytesFromUint8Array(_ array: JSValue) -> [UInt8] {
  let uint8Array = array.object!
  let length = Int(uint8Array.length.number!)
  var bytes = [UInt8]()
  bytes.reserveCapacity(length)
  for index in 0..<length {
    bytes.append(UInt8(uint8Array[index].number!))
  }
  return bytes
}
