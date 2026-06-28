import Configuration
import Foundation
import SystemPackage

public enum PackageConfig {
  /// Resolves the package root from a source file under `Sources/<target>/`.
  public static func packageRoot(fromFilePath sourceFile: String) -> URL {
    URL(fileURLWithPath: sourceFile)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  public static func reader(packageRoot: URL) async throws -> ConfigReader {
    let envFile = FilePath(packageRoot.appendingPathComponent(".env").path())
    return ConfigReader(providers: [
      EnvironmentVariablesProvider(),
      try await EnvironmentVariablesProvider(
        environmentFilePath: envFile,
        allowMissing: true
      ),
    ])
  }
}

public struct AppSettings: Sendable {
  public let hostname: String
  public let port: Int
  public let staticRoot: String
  public let skipShapeTreeWebBuild: Bool

  public static func load(packageRoot: URL) async throws -> AppSettings {
    let config = try await PackageConfig.reader(packageRoot: packageRoot)
    return AppSettings(
      hostname: config.string(forKey: "HOSTNAME", default: "127.0.0.1"),
      port: config.int(forKey: "PORT", default: 8080),
      staticRoot: config.string(forKey: "STATIC_ROOT", default: "dist"),
      skipShapeTreeWebBuild: config.bool(forKey: "SKIP_SHAPE_TREE_WEB_BUILD", default: false)
    )
  }
}
