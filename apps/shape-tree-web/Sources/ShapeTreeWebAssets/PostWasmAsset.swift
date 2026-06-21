import Foundation

public enum PostWasmAsset {
  public static let pages: [String: Data] = {
    guard let dirURL = Bundle.module.resourceURL?.appendingPathComponent("WasmPosts") else {
      return [:]
    }
    guard let files = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil) else {
      return [:]
    }
    var result: [String: Data] = [:]
    for file in files where file.pathExtension == "wasm" {
      let slug = file.deletingPathExtension().lastPathComponent
      if let data = try? Data(contentsOf: file) {
        result[slug] = data
      }
    }
    return result
  }()

  public static var isAvailable: Bool {
    !pages.isEmpty
  }

  public static func wasm(forSlug slug: String) -> Data? {
    pages[slug]
  }
}
