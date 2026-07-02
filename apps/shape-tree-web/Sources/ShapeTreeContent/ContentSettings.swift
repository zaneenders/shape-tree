import Configuration
import Foundation
import SystemPackage

public struct ContentSettings: Sendable {
  public let contentPath: String
  public let indexSlug: String
  public let loginSlug: String
  public let privateDirectories: Set<String>

  public static func load(from config: ConfigReader) throws -> ContentSettings {
    let rawPath = try config.requiredString(forKey: "CONTENT_PATH")
    let dirs = try config.requiredStringArray(forKey: "AUTH_PRIVATE_DIRECTORIES")
    return ContentSettings(
      contentPath: FilePath(expandingTildeIn: rawPath).string,
      indexSlug: try config.requiredString(forKey: "INDEX_PATH"),
      loginSlug: try config.requiredString(forKey: "LOGIN_PATH"),
      privateDirectories: Set(dirs))
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
