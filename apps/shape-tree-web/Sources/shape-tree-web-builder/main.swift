import Foundation
import ShapeTreeConfig
import ShapeTreeWebBuilder

@main
struct ShapeTreeWebCLI {
  static func main() async {
    do {
      let packageRoot = PackageConfig.packageRoot(fromFilePath: #filePath)
      try await ShapeTreeWebBuilder.run(packageRoot: packageRoot, configuration: .current)
    } catch {
      if let data = "error: \(error)\n".data(using: .utf8) {
        try? FileHandle.standardError.write(contentsOf: data)
      }
      exit(1)
    }
  }
}
