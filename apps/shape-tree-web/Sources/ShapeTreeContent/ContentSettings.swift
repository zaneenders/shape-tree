import Configuration
import Foundation

public struct ContentSettings: Sendable {
  public let contentPath: String
  public let indexSlug: String
  public let loginSlug: String
  public let privateDirectories: Set<String>

  public static func load(from config: ConfigReader) -> ContentSettings {
    let rawPath = config.string(forKey: "CONTENT_PATH", default: "~/content")
    return ContentSettings(
      contentPath: expandHomePath(rawPath),
      indexSlug: config.string(forKey: "INDEX_PATH", default: "Home"),
      loginSlug: config.string(forKey: "LOGIN_PATH", default: "login"),
      privateDirectories: parseDirectoryList(
        config.string(forKey: "AUTH_PRIVATE_DIRECTORIES", default: "")
      )
    )
  }

  public func makeStore() throws -> ContentStore {
    try ContentStore(
      contentDirectory: URL(fileURLWithPath: contentPath),
      indexSlug: indexSlug,
      loginSlug: loginSlug,
      privateDirectories: privateDirectories
    )
  }
}

public func expandHomePath(_ path: String) -> String {
  if path == "~" {
    return FileManager.default.homeDirectoryForCurrentUser.path
  }
  if path.hasPrefix("~/") {
    return (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
      .appendingPathComponent(String(path.dropFirst(2)))
  }
  return path
}

private func parseDirectoryList(_ value: String) -> Set<String> {
  Set(
    value
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  )
}
