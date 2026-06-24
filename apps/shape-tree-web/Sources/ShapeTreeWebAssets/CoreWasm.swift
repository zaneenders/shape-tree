import Foundation

public enum CoreWasm {
  /// Loaded once at first access; the embedded resource never changes at runtime.
  public static let bytes: Data = {
    guard
      let url = Bundle.module.url(forResource: "ShapeTreeCore", withExtension: "wasm"),
      let data = try? Data(contentsOf: url),
      !data.isEmpty
    else {
      fatalError(
        """
        ShapeTreeCore.wasm is missing or empty. Build the wasm client (requires wasm SDK):
          ./Scripts/build-core.sh
        JavaScriptKit glue is vendored under Sources/ShapeTreeWebAssets/client/.
        Refresh it after a JavaScriptKit bump with:
          ./Scripts/build-core.sh --regen-js
        """
      )
    }
    return data
  }()

  public static var isAvailable: Bool {
    !bytes.isEmpty
  }
}
