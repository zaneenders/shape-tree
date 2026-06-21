import Foundation

public enum PostWasmAsset {
  private static let wasmSubdirectory = "WasmPosts"

  private static let slugIndex: [String: Data] = {
    guard let dirURL = Bundle.module.resourceURL?.appendingPathComponent(wasmSubdirectory) else {
      return [:]
    }
    guard let files = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil) else {
      return [:]
    }
    var result: [String: Data] = [:]
    for file in files where file.pathExtension == "wasm" {
      let slug = file.deletingPathExtension().lastPathComponent
      if let data = try? Data(contentsOf: file), !data.isEmpty {
        result[slug] = data
      }
    }
    return result
  }()

  public static var isAvailable: Bool {
    !slugIndex.isEmpty
  }

  public static var availableSlugs: [String] {
    slugIndex.keys.sorted()
  }

  public static func wasm(forSlug rawSlug: String) -> Data? {
    for candidate in slugCandidates(for: rawSlug) {
      if let data = slugIndex[candidate] {
        return data
      }
      if let url = Bundle.module.url(
        forResource: candidate,
        withExtension: "wasm",
        subdirectory: wasmSubdirectory
      ), let data = try? Data(contentsOf: url), !data.isEmpty {
        return data
      }
    }
    return nil
  }

  public static func slugCandidates(for rawSlug: String) -> [String] {
    var candidates: [String] = []
    if let decoded = rawSlug.removingPercentEncoding, decoded != rawSlug {
      candidates.append(decoded)
    }
    candidates.append(rawSlug)
    if rawSlug.contains("+") {
      candidates.append(rawSlug.replacingOccurrences(of: "+", with: " "))
    }
    var seen = Set<String>()
    return candidates.filter { seen.insert($0).inserted }
  }
}
