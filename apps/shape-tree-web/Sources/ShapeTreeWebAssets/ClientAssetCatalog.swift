import Foundation

/// Maps `/assets/client/*` request paths to embedded build artifacts.
public enum ClientAssetCatalog {
  public enum Entry: Sendable {
    case script(String)
    case wasm(Data)
  }

  public static var isAvailable: Bool {
    CoreWasm.isAvailable
  }

  public static func entry(forRelativePath path: String) -> Entry? {
    switch path {
    case "ShapeTreeCore.wasm":
      guard CoreWasm.isAvailable else { return nil }
      return .wasm(CoreWasm.bytes)
    case "index.js":
      return .script(client_index_js)
    case "bootstrap.js":
      return .script(bootstrap_js)
    case "instantiate.js":
      return .script(client_instantiate_js)
    case "runtime.js":
      return .script(client_runtime_js)
    case "bridge-js.js":
      return .script(client_bridge_js_js)
    case "page-instantiate.js":
      return .script(client_page_instantiate_js)
    case "platforms/browser.js":
      return .script(client_platforms_browser_js)
    case "browser_wasi_shim.js":
      return .script(Vendor_browser_wasi_shim_js)
    default:
      return nil
    }
  }
}
