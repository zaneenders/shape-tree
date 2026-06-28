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
    let secretKeys = SecretsSpecifier<String, String>.specific([
      "PGPASSWORD", "SMTP_PASSWORD",
    ])
    let envFile = FilePath(packageRoot.appendingPathComponent(".env").path())
    return ConfigReader(providers: [
      EnvironmentVariablesProvider(secretsSpecifier: secretKeys),
      try await EnvironmentVariablesProvider(
        environmentFilePath: envFile,
        allowMissing: true,
        secretsSpecifier: secretKeys
      ),
    ])
  }
}

public struct AppSettings: Sendable {
  public let hostname: String
  public let port: Int
  public let adminHost: String
  public let adminPort: Int
  public let staticRoot: String
  public let siteURL: String
  public let skipShapeTreeWebBuild: Bool

  public static func load(packageRoot: URL) async throws -> AppSettings {
    let config = try await PackageConfig.reader(packageRoot: packageRoot)
    let port = config.int(forKey: "PORT", default: 8080)
    let defaultSiteURL = "http://127.0.0.1:\(port)"
    return AppSettings(
      hostname: config.string(forKey: "HOSTNAME", default: "127.0.0.1"),
      port: port,
      adminHost: config.string(forKey: "ADMIN_HOST", default: "127.0.0.1"),
      adminPort: config.int(forKey: "ADMIN_PORT", default: 42070),
      staticRoot: config.string(forKey: "STATIC_ROOT", default: "dist"),
      siteURL: config.string(forKey: "SITE_URL", default: defaultSiteURL),
      skipShapeTreeWebBuild: config.bool(forKey: "SKIP_SHAPE_TREE_WEB_BUILD", default: false)
    )
  }
}
