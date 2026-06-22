import Foundation
import Markdown

@main
struct ContentGenerator {
  static func main() {
    let args = CommandLine.arguments
    guard args.count >= 6 else {
      FileHandle.standardError.write(
        Data(
          """
          Usage: ContentGenerator <output-pages-dir> <output-package-swift> <output-manifest> \
          <output-meta-dir> <content-source-root> <input.md> [<input.md> ...]

          """.utf8))
      exit(1)
    }

    let outputPagesDir = args[1]
    let outputPackageSwift = args[2]
    let outputManifest = args[3]
    let outputMetaDir = args[4]
    let sourceRoot = URL(fileURLWithPath: args[5]).standardizedFileURL
    let inputFiles = Array(args.dropFirst(6))

    var pages: [(path: String, title: String, html: String)] = []

    for path in inputFiles {
      guard path.hasSuffix(".md") else { continue }
      guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("Warning: could not read \(path)\n".utf8))
        continue
      }
      let fileURL = URL(fileURLWithPath: path).standardizedFileURL
      let relativePath = fileURL.path(from: sourceRoot)
      let contentPath = (relativePath as NSString).deletingPathExtension
      let (title, _, _) = splitFrontMatter(source, path: contentPath)
      let html = renderArticle(source: source, path: contentPath, title: title)
      pages.append((contentPath, title ?? humanize(contentPath), html))
    }

    pages.sort { $0.path < $1.path }

    try? FileManager.default.createDirectory(
      atPath: outputPagesDir, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(
      atPath: outputMetaDir, withIntermediateDirectories: true)

    for (path, title, html) in pages {
      let safeName = safeTargetName(path)
      let escaped = escapeSwiftString(html)
      let fileContent = """
        // GENERATED FILE — do not edit.
        // Page: \(path)
        import JavaScriptKit

        @main
        struct \(safeName) {
          static func main() {
            let document = JSObject.global.document
            if let main = document.getElementById("main").object {
              main.innerHTML = .string(JSString("\(escaped)"))
              _ = JSObject.global.console.log("[post-wasm] rendered page")
            }
          }
        }
        """

      let outputPath = "\(outputPagesDir)/\(safeName).swift"
      try? fileContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
      writeMeta(title: title, contentPath: path, outputMetaDir: outputMetaDir)
    }

    var pkg = "// swift-tools-version: 6.3\n\n"
    pkg += "import PackageDescription\n\n"
    pkg += "let package = Package(\n"
    pkg += "  name: \"WasmPost\",\n"
    pkg += "  platforms: [.macOS(.v26)],\n"
    pkg += "  dependencies: [\n"
    pkg += "    .package(url: \"https://github.com/swiftwasm/JavaScriptKit.git\", from: \"0.37.0\"),\n"
    pkg += "  ],\n"
    pkg += "  targets: [\n"
    for (path, _, _) in pages {
      let safeName = safeTargetName(path)
      pkg += "    .executableTarget(\n"
      pkg += "      name: \"\(safeName)\",\n"
      pkg += "      dependencies: [.product(name: \"JavaScriptKit\", package: \"JavaScriptKit\")],\n"
      pkg += "      path: \"Sources/Pages\",\n"
      pkg += "      sources: [\"\(safeName).swift\"],\n"
      pkg += "      swiftSettings: [\n"
      pkg += "        .enableExperimentalFeature(\"Extern\"),\n"
      pkg += "        .swiftLanguageMode(.v5),\n"
      pkg += "        .unsafeFlags([\"-Osize\"], .when(configuration: .release)),\n"
      pkg += "      ]\n"
      pkg += "    ),\n"
    }
    pkg += "  ]\n"
    pkg += ")\n"

    try? pkg.write(toFile: outputPackageSwift, atomically: true, encoding: .utf8)

    var manifest = ""
    for (path, _, _) in pages {
      let safeName = safeTargetName(path)
      manifest += "\(safeName)=\(path)\n"
    }
    try? manifest.write(toFile: outputManifest, atomically: true, encoding: .utf8)

    FileHandle.standardOutput.write(
      Data("Generated \(pages.count) page(s)\n".utf8))
  }

  static func writeMeta(title: String, contentPath: String, outputMetaDir: String) {
    let meta = MetaSidecar(title: title)
    guard let data = try? JSONEncoder().encode(meta) else { return }
    let destination = URL(fileURLWithPath: outputMetaDir)
      .appendingPathComponent(contentPath)
      .appendingPathExtension("meta.json")
    try? FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? data.write(to: destination)
  }

  static func safeTargetName(_ path: String) -> String {
    let sanitized = path.map { c in
      if c.isLetter || c.isNumber { String(c) } else { "_" }
    }.joined()
    return "Page_" + sanitized
  }

  static func escapeSwiftString(_ s: String) -> String {
    s
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "")
      .replacingOccurrences(of: "\t", with: "\\t")
  }

  static func renderArticle(source: String, path: String, title: String?) -> String {
    let (parsedTitle, date, body) = splitFrontMatter(source, path: path)
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
    if let date {
      html += "<p class=\"post-meta\">\(escapeHTML(date))</p>"
    }
    html += "<div class=\"post-body\">\(bodyHTML)</div></article>"
    return html
  }

  static func splitFrontMatter(
    _ source: String, path: String
  ) -> (title: String?, date: String?, body: String) {
    let lines = source.components(separatedBy: "\n")

    guard let first = lines.first,
      first.trimmingCharacters(in: .whitespaces).hasPrefix("---")
    else {
      return (nil, nil, source)
    }

    var endIdx: Int?
    for i in 1..<lines.count {
      let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("---") {
        endIdx = i
        break
      }
    }

    guard let endIdx else { return (nil, nil, source) }

    let fmLines = lines[1..<endIdx]
    let bodyLines = lines[(endIdx + 1)...]

    var title: String?
    var date: String?
    for line in fmLines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("title:") {
        title = stripValue(trimmed.dropFirst(6))
      } else if trimmed.hasPrefix("date:") {
        date = stripValue(trimmed.dropFirst(5))
      }
    }

    return (title, date, bodyLines.joined(separator: "\n"))
  }

  static func stripValue<S: StringProtocol>(_ s: S) -> String {
    var v = String(s).trimmingCharacters(in: .whitespaces)
    if v.count >= 2,
      (v.hasPrefix("\"") && v.hasSuffix("\""))
        || (v.hasPrefix("'") && v.hasSuffix("'"))
    {
      v = String(v.dropFirst().dropLast())
    }
    return v
  }

  static func humanize(_ path: String) -> String {
    let name = (path as NSString).lastPathComponent
    return name
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  static func escapeHTML(_ s: String) -> String {
    s
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}

struct MetaSidecar: Codable {
  var title: String
}

extension URL {
  fileprivate func path(from root: URL) -> String {
    let rootPath = root.standardizedFileURL.path + "/"
    let fullPath = standardizedFileURL.path
    if fullPath.hasPrefix(rootPath) {
      return String(fullPath.dropFirst(rootPath.count))
    }
    return lastPathComponent
  }
}
