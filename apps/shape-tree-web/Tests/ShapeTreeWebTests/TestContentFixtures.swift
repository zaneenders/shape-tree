import Foundation
import ShapeTreeWebCore

enum TestContentFixtures {
  static let wasmBytes = Data([0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00])

  @discardableResult
  static func writeNode(in root: URL, path: String, title: String) throws -> URL {
    let wasmURL = root.appendingPathComponent("\(path).wasm")
    try FileManager.default.createDirectory(
      at: wasmURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try wasmBytes.write(to: wasmURL)
    let metaURL = root.appendingPathComponent("\(path).meta.json")
    try JSONSerialization.data(withJSONObject: ["title": title]).write(to: metaURL)
    return wasmURL
  }

  static func makeStore(
    nodes: [(path: String, title: String)],
    indexPath: String = "Home",
    siteTitle: String? = nil,
    privateDirectories: Set<String> = []
  ) throws -> ContentStore {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-content-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for node in nodes {
      try writeNode(in: root, path: node.path, title: node.title)
    }
    return try ContentStore(
      contentDirectory: root,
      indexPath: indexPath,
      siteTitle: siteTitle,
      privateDirectories: privateDirectories
    )
  }
}
