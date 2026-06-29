import Configuration
import Foundation
import NIOFileSystem
import ShapeTreeConfig
import Subprocess
import SystemPackage

#if canImport(System)
import System
private typealias SubprocessFilePath = System.FilePath
#else
private typealias SubprocessFilePath = SystemPackage.FilePath
#endif

public enum ShapeTreeWebBuilderError: Error {
  case commandFailed(String, Int32)
  case noExecutableProducts
}

public enum ShapeTreeWebBuilder {

  private static let packageOutputsBasePath = ".build"
  private static let wasmPluginsOutputRelativePath = "plugins/PackageToJS/outputs"
  private static let distRelativePath = "dist"

  public static func run(packageRoot: URL, configuration: Configuration? = nil) async throws {
    let config = try await PackageConfig.reader(packageRoot: packageRoot)
    let buildConfiguration = configuration ?? Configuration.resolved(config)
    let frontendDir = packageRoot.appendingPathComponent("frontend", isDirectory: true)
    let pluginsOutputDir =
      frontendDir
      .appendingPathComponent(packageOutputsBasePath, isDirectory: true)
      .appendingPathComponent(wasmPluginsOutputRelativePath, isDirectory: true)
    let distDir = packageRoot.appendingPathComponent(distRelativePath, isDirectory: true)

    let swiftSDK = config.string(forKey: "SWIFT_SDK_ID", default: "swift-6.3.2-RELEASE_wasm-embedded")
    let frontendPath = SubprocessFilePath(frontendDir.path())

    let products = try await discoverExecutableProducts(in: frontendPath)
    guard !products.isEmpty else {
      throw ShapeTreeWebBuilderError.noExecutableProducts
    }

    print("shape-tree-web: building \(products.count) WASM frontend product(s) (\(buildConfiguration.rawValue))…")

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { [frontendPath] in
        try await runCommand("bun", arguments: ["install", "--frozen-lockfile"], in: frontendPath)
      }

      for product in products {
        let scratchPath = ".build-\(product)"
        let productOutputDir = pluginsOutputDir.appendingPathComponent(product, isDirectory: true)
        let productWasmOutput = productOutputDir.appendingPathComponent("\(product).wasm")
        let buildConfiguration = buildConfiguration
        let swiftSDK = swiftSDK
        let frontendPath = frontendPath

        group.addTask {
          print("shape-tree-web: building WASM frontend product '\(product)' (\(buildConfiguration.rawValue))…")
          try await runCommand(
            "swift",
            arguments: [
              "package",
              "--scratch-path", scratchPath,
              "--swift-sdk", swiftSDK,
              "--allow-writing-to-package-directory",
              "js",
              "--product", product,
              "--output", productOutputDir.path,
              "-c", buildConfiguration.rawValue,
            ],
            in: frontendPath
          )
        }
      }

      try await group.waitForAll()
    }

    try await fileSystemCreateDist(distDir)

    try await runCommand(
      "bun",
      arguments: ["run", "build.ts"],
      in: frontendPath
    )
  }

  private static func discoverExecutableProducts(in workingDirectory: SubprocessFilePath) async throws -> [String] {
    let result = try await Subprocess.run(
      .name("swift"),
      arguments: Arguments(["package", "show-executables"]),
      workingDirectory: workingDirectory,
      output: .string(limit: 64 * 1024),
      error: .currentStandardError
    )
    guard result.terminationStatus.isSuccess else {
      let code: Int32 =
        switch result.terminationStatus {
        case .exited(let code): Int32(code)
        case .signaled(let signal): Int32(signal)
        }
      throw ShapeTreeWebBuilderError.commandFailed("swift", code)
    }
    return (result.standardOutput ?? "")
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.contains("(") }
  }

  private static func runCommand(
    _ command: String,
    arguments: [String],
    in workingDirectory: SubprocessFilePath? = nil
  ) async throws {
    let result = try await Subprocess.run(
      .name(command),
      arguments: Arguments(arguments),
      workingDirectory: workingDirectory,
      output: .currentStandardOutput,
      error: .currentStandardError
    )
    guard result.terminationStatus.isSuccess else {
      let code: Int32 =
        switch result.terminationStatus {
        case .exited(let code): Int32(code)
        case .signaled(let signal): Int32(signal)
        }
      throw ShapeTreeWebBuilderError.commandFailed(command, code)
    }
  }

  private static func fileSystemCreateDist(_ distDir: URL) async throws {
    let fileSystem = FileSystem.shared
    let distPath = FilePath(distDir.path())
    try await fileSystem.createDirectory(at: distPath, withIntermediateDirectories: true)

    if let entries = try? FileManager.default.contentsOfDirectory(at: distDir, includingPropertiesForKeys: nil) {
      for entry in entries where entry.pathExtension == "js" {
        try FileManager.default.removeItem(at: entry)
      }
    }
  }

  public enum Configuration: String, Sendable {
    case debug
    case release

    /// Matches how the calling executable was built (`swift run` vs `swift run -c release`).
    public static var current: Configuration {
      #if DEBUG
      .debug
      #else
      .release
      #endif
    }

    public static func from(_ config: ConfigReader) -> Configuration {
      for key in ["SWIFT_BUILD_CONFIGURATION", "CONFIGURATION", "BUILD_CONFIGURATION"] {
        if config.string(forKey: ConfigKey(key))?.lowercased() == Configuration.release.rawValue {
          return .release
        }
      }
      return .debug
    }

    /// Env override when set; otherwise matches the calling executable's build configuration.
    public static func resolved(_ config: ConfigReader) -> Configuration {
      for key in ["SWIFT_BUILD_CONFIGURATION", "CONFIGURATION", "BUILD_CONFIGURATION"] {
        if let value = config.string(forKey: ConfigKey(key))?.lowercased() {
          return value == Configuration.release.rawValue ? .release : .debug
        }
      }
      return .current
    }
  }
}
