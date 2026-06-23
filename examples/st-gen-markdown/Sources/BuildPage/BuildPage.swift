import Foundation
import Markdown

@main
struct BuildPage {
  static func main() {
    let args = Array(CommandLine.arguments.dropFirst())

    do {
      let opts = try Options.parse(args)
      try run(opts: opts)
    } catch let e as CLIError {
      FileHandle.standardError.write(Data("error: \(e.message)\n".utf8))
      exit(1)
    } catch {
      FileHandle.standardError.write(Data("error: \(error)\n".utf8))
      exit(1)
    }
  }

  static func run(opts: Options) throws {
    let packageURL = URL(fileURLWithPath: opts.packageRoot)
      .standardizedFileURL
    let contentSrcURL =
      URL(fileURLWithPath: opts.contentSrc, relativeTo: packageURL)
      .standardizedFileURL
    let outputURL =
      URL(fileURLWithPath: opts.output, relativeTo: packageURL)
      .standardizedFileURL
    let scratchURL =
      packageURL.appendingPathComponent(".build/wasm")

    log("package root: \(packageURL.path)")
    log("content-src:  \(contentSrcURL.path)")
    log("output:       \(outputURL.path)")
    log("sdk:          \(opts.sdk)")
    log("scratch:      \(scratchURL.path)")

    guard let mdArg = opts.mdPath else {
      FileHandle.standardError.write(
        Data(
          """
          Usage: BuildPage <path-to.md> [options]
            --package-root <path>  Package root (default: current directory)
            --sdk <name>           SwiftWasm SDK (default: $SWIFT_WASM_SDK or swift-6.3.2-RELEASE_wasm-embedded)
            --content-src <path>   Content source root (default: ../content-src)
            --output <path>        Wasm output dir (default: content)
            --login-slug <slug>    Skip pages matching this slug (default: login)
            -v, --verbose          Print detailed progress

          """.utf8))
      exit(1)
    }

    let mdURL =
      URL(fileURLWithPath: mdArg, relativeTo: packageURL)
      .standardizedFileURL
    guard FileManager.default.fileExists(atPath: mdURL.path) else {
      throw CLIError("Markdown file not found: \(mdURL.path)")
    }

    let contentPath = deriveContentPath(
      mdURL: mdURL, contentSrcURL: contentSrcURL)
    log("content path: \(contentPath)")

    if (mdURL.lastPathComponent as NSString)
      .deletingPathExtension.lowercased()
      == opts.loginSlug.lowercased()
    {
      log("Skipping login page: \(contentPath)")
      return
    }

    log("Reading markdown: \(mdURL.lastPathComponent)")
    let source = try String(contentsOf: mdURL, encoding: .utf8)
    let (title, _, _) = splitFrontMatter(source)
    let html = renderArticle(
      source: source, path: contentPath, title: title)
    let resolvedTitle = title ?? humanize(contentPath)
    log("page title:     \(resolvedTitle)")

    // Write generated Swift + a throwaway Package.swift into a temp
    // mini-package under .build/.  The SPM cache (compiled JavaScriptKit)
    // persists between runs so only Page.swift is recompiled.
    let tempPkgDir = scratchURL.appendingPathComponent("page-pkg")
    let tempSrcDir = tempPkgDir.appendingPathComponent("Sources/Page")
    let tempBuildDir = tempPkgDir.appendingPathComponent(".build")

    let wasmClientPath = URL(fileURLWithPath: opts.packageRoot, isDirectory: true)
      .appendingPathComponent("../../apps/wasm-client")
      .standardizedFileURL.path

    log("Writing temp package -> \(tempPkgDir.path)")
    try FileManager.default.createDirectory(
      at: tempSrcDir, withIntermediateDirectories: true)
    try tempPackageSwift(wasmClientPath: wasmClientPath).write(
      to: tempPkgDir.appendingPathComponent("Package.swift"),
      atomically: true, encoding: .utf8)
    let swiftSource = generatePageSwift(
      contentPath: contentPath, html: html, title: resolvedTitle)
    try swiftSource.write(
      to: tempSrcDir.appendingPathComponent("Page.swift"),
      atomically: true, encoding: .utf8)

    let metaDir =
      packageURL.appendingPathComponent(".build/meta")
    log("Writing meta -> \(metaDir.path)/\(contentPath).meta.json")
    try FileManager.default.createDirectory(
      at: metaDir, withIntermediateDirectories: true)
    let metaURL = metaDir.appendingPathComponent(contentPath)
      .appendingPathExtension("meta.json")
    try FileManager.default.createDirectory(
      at: metaURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    let metaData = try JSONEncoder().encode(
      MetaSidecar(title: resolvedTitle))
    try metaData.write(to: metaURL)

    let outputDir = tempPkgDir.appendingPathComponent("js")
    log("Cleaning output dir: \(outputDir.path)")
    try? FileManager.default.removeItem(at: outputDir)

    try runSwiftPackageJs(
      target: "Page",
      sdk: opts.sdk,
      outputDir: outputDir,
      packageURL: tempPkgDir,
      scratchURL: tempBuildDir,
      verbose: opts.verbose
    )

    let wasmFile = outputDir.appendingPathComponent("Page.wasm")
    guard FileManager.default.fileExists(atPath: wasmFile.path) else {
      throw CLIError("wasm output missing: \(wasmFile.path)")
    }
    log("wasm built: \(wasmFile.path) (\(fileSize(wasmFile)) bytes)")

    log("Running wasm-opt -Oz")
    try runWasmOpt(wasmFile: wasmFile, verbose: opts.verbose)
    log("wasm optimized: \(fileSize(wasmFile)) bytes")

    let destWasm =
      outputURL.appendingPathComponent(contentPath)
      .appendingPathExtension("wasm")
    log("Copying wasm -> \(destWasm.path)")
    try? FileManager.default.removeItem(at: destWasm)
    try FileManager.default.createDirectory(
      at: destWasm.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: wasmFile, to: destWasm)

    let bridgeFile = outputDir.appendingPathComponent("bridge-js.js")
    guard FileManager.default.fileExists(atPath: bridgeFile.path) else {
      throw CLIError("bridge-js.js missing: \(bridgeFile.path)")
    }
    let destBridge =
      outputURL.appendingPathComponent(contentPath)
      .appendingPathExtension("bridge-js.js")
    log("Copying bridge-js -> \(destBridge.path)")
    try? FileManager.default.removeItem(at: destBridge)
    try FileManager.default.createDirectory(
      at: destBridge.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: bridgeFile, to: destBridge)

    let metaDest =
      outputURL.appendingPathComponent(contentPath)
      .appendingPathExtension("meta.json")
    log("Copying meta -> \(metaDest.path)")
    try? FileManager.default.removeItem(at: metaDest)
    try FileManager.default.createDirectory(
      at: metaDest.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: metaURL, to: metaDest)

    log("Done: \(contentPath) -> \(destWasm.path)")
  }

  // MARK: - Subprocesses

  static func runSwiftPackageJs(
    target: String,
    sdk: String,
    outputDir: URL,
    packageURL: URL,
    scratchURL: URL,
    verbose: Bool
  ) throws {
    let process = Process()
    process.currentDirectoryURL = packageURL

    var env = ProcessInfo.processInfo.environment
    env.removeValue(forKey: "JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM")
    process.environment = env

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "swift", "package",
      "--scratch-path", scratchURL.path,
      "--swift-sdk", sdk,
      "--allow-writing-to-package-directory",
      "js",
      "--product", target,
      "--output", outputDir.path,
      "--configuration", "release",
      "--debug-info-format", "none",
    ]

    log("Running: \(process.arguments!.joined(separator: " "))")

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
    let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()

    if verbose {
      if let s = String(data: stdoutData, encoding: .utf8), !s.isEmpty {
        FileHandle.standardError.write(Data(s.utf8))
      }
      if let s = String(data: stderrData, encoding: .utf8), !s.isEmpty {
        FileHandle.standardError.write(Data(s.utf8))
      }
    }

    if process.terminationStatus != 0 {
      if let s = String(data: stderrData, encoding: .utf8), !s.isEmpty {
        FileHandle.standardError.write(Data(s.utf8))
      }
      if let s = String(data: stdoutData, encoding: .utf8), !s.isEmpty {
        FileHandle.standardError.write(Data(s.utf8))
      }
      throw CLIError("swift package js failed for \(target) (exit \(process.terminationStatus))")
    }
  }

  static func runWasmOpt(wasmFile: URL, verbose: Bool) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "wasm-opt", "-Oz", "--strip-debug", "--strip-producers",
      wasmFile.path, "-o", wasmFile.path,
    ]

    if verbose { log("Running: \(process.arguments!.joined(separator: " "))") }

    let stderr = Pipe()
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
      let data = stderr.fileHandleForReading.readDataToEndOfFile()
      if let s = String(data: data, encoding: .utf8) {
        FileHandle.standardError.write(Data(s.utf8))
      }
      throw CLIError("wasm-opt failed (exit \(process.terminationStatus))")
    }
  }

  // MARK: - Temp package + Markdown -> Swift source

  static func tempPackageSwift(wasmClientPath: String) -> String {
    let escapedPath = wasmClientPath.replacingOccurrences(of: "\\", with: "\\\\")
    return """
    // swift-tools-version: 6.3
    // Throwaway package generated by BuildPage — do not edit.
    import PackageDescription

    let package = Package(
      name: "Page",
      dependencies: [
        .package(path: "\(escapedPath)"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.55.0"),
      ],
      targets: [
        .executableTarget(
          name: "Page",
          dependencies: [
            .product(name: "ShapeTreeKit", package: "wasm-client"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
          ],
          swiftSettings: [
            .enableExperimentalFeature("Extern"),
            .swiftLanguageMode(.v6),
            .unsafeFlags(["-Osize"], .when(configuration: .release)),
          ],
          linkerSettings: [
            .unsafeFlags(["-Xlinker", "-lswiftUnicodeDataTables"])
          ],
          plugins: [
            .plugin(name: "BridgeJS", package: "JavaScriptKit")
          ]
        ),
      ]
    )
    """
  }

  static func generatePageSwift(
    contentPath: String, html: String, title: String
  ) -> String {
    let escapedHTML = escapeSwiftString(html)
    let escapedPath = escapeSwiftString(contentPath)
    let escapedTitle = escapeSwiftString(title)
    return """
      // GENERATED FILE - do not edit.
      // Page: \(contentPath)
      import JavaScriptKit
      import ShapeTreeKit

      @main
      struct Page {
        static func main() {
          PageMessaging.renderHTML(intoMain: "\(escapedHTML)")
          PageMessaging.ready(path: "\(escapedPath)")
          PageMessaging.setTitle("\(escapedTitle)")
        }
      }

      @JS public func handleShellMessage(_ message: JSObject) {
        let shellMessage = ShellMessage(unsafelyCopying: message)
        switch shellMessage.kind {
        case ShellMessageKind.teardown:
          PageMessaging.log("[page] teardown \(escapedPath)")
        default:
          PageMessaging.log("[page] shell message: \\(shellMessage.kind)")
        }
      }
      """
  }

  static func renderArticle(source: String, path: String, title: String?) -> String {
    let (parsedTitle, date, body) = splitFrontMatter(source)
    let doc = Document(parsing: body)

    var titleToUse = title ?? parsedTitle ?? humanize(path)
    var bodyBlocks: [BlockMarkup] = []

    if let heading = doc.child(at: 0) as? Heading, heading.level == 1 {
      titleToUse = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
      bodyBlocks = doc.children.dropFirst().compactMap { $0 as? BlockMarkup }
    } else {
      bodyBlocks = doc.children.compactMap { $0 as? BlockMarkup }
    }

    let bodyHTML = HTMLFormatter.format(Document(bodyBlocks))

    var html = "<article><h1>\(escapeHTML(titleToUse))</h1>"
    if let date { html += "<p class=\"post-meta\">\(escapeHTML(date))</p>" }
    html += "<div class=\"post-body\">\(bodyHTML)</div></article>"
    return html
  }

  static func splitFrontMatter(_ source: String) -> (title: String?, date: String?, body: String) {
    let lines = source.components(separatedBy: "\n")
    guard let first = lines.first,
      first.trimmingCharacters(in: .whitespaces).hasPrefix("---")
    else { return (nil, nil, source) }

    var endIdx: Int?
    for i in 1..<lines.count {
      if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("---") {
        endIdx = i; break
      }
    }
    guard let endIdx else { return (nil, nil, source) }

    var title: String?
    var date: String?
    for line in lines[1..<endIdx] {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("title:") { title = stripValue(trimmed.dropFirst(6)) }
      else if trimmed.hasPrefix("date:") { date = stripValue(trimmed.dropFirst(5)) }
    }
    return (title, date, lines[(endIdx + 1)...].joined(separator: "\n"))
  }

  static func stripValue<S: StringProtocol>(_ s: S) -> String {
    var v = String(s).trimmingCharacters(in: .whitespaces)
    if v.count >= 2,
      (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'"))
    { v = String(v.dropFirst().dropLast()) }
    return v
  }

  static func deriveContentPath(mdURL: URL, contentSrcURL: URL) -> String {
    let basePath = contentSrcURL.path + "/"
    let fullPath = mdURL.path
    if fullPath.hasPrefix(basePath) {
      let relative = String(fullPath.dropFirst(basePath.count))
      return (relative as NSString).deletingPathExtension
    }
    return (mdURL.lastPathComponent as NSString).deletingPathExtension
  }

  static func humanize(_ path: String) -> String {
    (path as NSString).lastPathComponent
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  static func escapeSwiftString(_ s: String) -> String {
    s
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "")
      .replacingOccurrences(of: "\t", with: "\\t")
  }

  static func escapeHTML(_ s: String) -> String {
    s
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }

  static func log(_ message: String) {
    FileHandle.standardError.write(Data("[build-page] \(message)\n".utf8))
  }

  static func fileSize(_ url: URL) -> Int {
    (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
  }
}

// MARK: - Options

struct Options {
  var mdPath: String?
  var sdk: String
  var packageRoot: String
  var contentSrc: String
  var output: String
  var loginSlug: String
  var verbose: Bool

  static func parse(_ args: [String]) throws -> Options {
    let env = ProcessInfo.processInfo.environment
    var o = Options(
      mdPath: nil,
      sdk: env["SWIFT_WASM_SDK"] ?? "swift-6.3.2-RELEASE_wasm-embedded",
      packageRoot: FileManager.default.currentDirectoryPath,
      contentSrc: "../content-src",
      output: "content",
      loginSlug: "login",
      verbose: false
    )

    var i = 0
    while i < args.count {
      let a = args[i]
      switch a {
      case "--sdk":
        guard i + 1 < args.count else { throw CLIError("--sdk requires a value") }
        o.sdk = args[i + 1]; i += 2
      case "--package-root":
        guard i + 1 < args.count else { throw CLIError("--package-root requires a value") }
        o.packageRoot = args[i + 1]; i += 2
      case "--content-src":
        guard i + 1 < args.count else { throw CLIError("--content-src requires a value") }
        o.contentSrc = args[i + 1]; i += 2
      case "--output":
        guard i + 1 < args.count else { throw CLIError("--output requires a value") }
        o.output = args[i + 1]; i += 2
      case "--login-slug":
        guard i + 1 < args.count else { throw CLIError("--login-slug requires a value") }
        o.loginSlug = args[i + 1]; i += 2
      case "-v", "--verbose":
        o.verbose = true; i += 1
      case "--help", "-h":
        FileHandle.standardError.write(
          Data(
            """
            Usage: BuildPage <path-to.md> [options]
              --package-root <path>  Package root (default: current directory)
              --sdk <name>           SwiftWasm SDK (default: $SWIFT_WASM_SDK or swift-6.3.2-RELEASE_wasm-embedded)
              --content-src <path>   Content source root (default: ../content-src)
              --output <path>        Wasm output dir (default: content)
              --login-slug <slug>    Skip pages matching this slug (default: login)
              -v, --verbose          Print detailed progress (including subprocess output)

            """.utf8))
        exit(0)
      default:
        if a.hasPrefix("-") { throw CLIError("Unknown option: \(a)") }
        if o.mdPath != nil { throw CLIError("Only one markdown path may be passed") }
        o.mdPath = a; i += 1
      }
    }
    return o
  }
}

// MARK: - Errors & models

struct CLIError: Error, CustomStringConvertible {
  let message: String
  init(_ message: String) { self.message = message }
  var description: String { message }
}

struct MetaSidecar: Codable {
  var title: String
}
