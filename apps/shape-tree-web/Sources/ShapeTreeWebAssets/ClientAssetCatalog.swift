import Foundation

/// Maps `/assets/client/*` request paths to embedded build artifacts.
public enum ClientAssetCatalog {
  public enum Entry: Sendable {
    case script(String)
    case wasm(Data)
  }

  public static var isAvailable: Bool {
    NavWasm.isAvailable
  }

  public static func entry(forRelativePath path: String) -> Entry? {
    switch path {
    case "WASMNav.wasm":
      guard NavWasm.isAvailable else { return nil }
      return .wasm(NavWasm.bytes)
    case "index.js":
      return .script(client_index_js)
    case "instantiate.js":
      return .script(client_instantiate_js)
    case "runtime.js":
      return .script(client_runtime_js)
    case "platforms/browser.js":
      return .script(client_platforms_browser_js)
    case "browser_wasi_shim.js":
      return .script(Vendor_browser_wasi_shim_js)
    default:
      return nil
    }
  }
}
