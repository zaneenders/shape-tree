import Foundation

/// Maps `/assets/nav-client/*` request paths to embedded build artifacts.
public enum NavClientAssetCatalog {
  public enum Entry: Sendable {
    case script(String)
    case wasm(Data)
  }

  public static var isAvailable: Bool {
    NavClientWasm.isAvailable
  }

  public static func entry(forRelativePath path: String) -> Entry? {
    switch path {
    case "WASMClient.wasm":
      guard NavClientWasm.isAvailable else { return nil }
      return .wasm(NavClientWasm.bytes)
    case "index.js":
      return .script(nav_client_index_js)
    case "instantiate.js":
      return .script(nav_client_instantiate_js)
    case "runtime.js":
      return .script(nav_client_runtime_js)
    case "platforms/browser.js":
      return .script(nav_client_platforms_browser_js)
    default:
      return nil
    }
  }
}
