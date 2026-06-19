import Foundation

public enum NavClientWasm {
  public static var bytes: Data {
    guard
      let url = Bundle.module.url(forResource: "NavClientWasm", withExtension: "wasm"),
      let data = try? Data(contentsOf: url),
      !data.isEmpty
    else {
      return Data()
    }
    return data
  }

  public static var isAvailable: Bool {
    !bytes.isEmpty
  }
}
