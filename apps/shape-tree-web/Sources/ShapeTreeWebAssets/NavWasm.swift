import Foundation

public enum NavWasm {
  /// Loaded once at first access; the embedded resource never changes at runtime.
  public static let bytes: Data = {
    guard
      let url = Bundle.module.url(forResource: "WASMNav", withExtension: "wasm"),
      let data = try? Data(contentsOf: url),
      !data.isEmpty
    else {
      fatalError(
        """
        WASMNav.wasm is missing or empty. Build the wasm client before launching the server:
          ./Scripts/build-client.sh
        """
      )
    }
    return data
  }()

  public static var isAvailable: Bool {
    !bytes.isEmpty
  }
}
