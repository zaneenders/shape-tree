import Foundation
import NIOCore
import _NIOFileSystem

enum NodeStorage {
  static let nodesDirectoryName = "nodes"
  static let manifestFileName = "node.json"

  static func nodesDirectory(in dataDirectory: FilePath) -> FilePath {
    dataDirectory.appending(nodesDirectoryName)
  }

  static func nodeDirectory(in nodesDirectory: FilePath, id: NodeID) -> FilePath {
    nodesDirectory.appending(id.description)
  }

  static func manifestFile(in nodeDirectory: FilePath) -> FilePath {
    nodeDirectory.appending(manifestFileName)
  }

  static func encode<Payload: Codable & Sendable>(_ node: TreeNode<Payload>) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(node)
  }

  static func decode<Payload: Codable & Sendable>(from data: Data) throws -> TreeNode<Payload> {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(TreeNode<Payload>.self, from: data)
  }
}

struct NodeDirectoryLoader<Payload: Codable & Sendable>: Sendable {
  let fileSystem: FileSystem

  func loadNodes(from nodesDirectory: FilePath) async throws -> [TreeNode<Payload>] {
    guard let info = try await fileSystem.info(forFileAt: nodesDirectory), info.type == .directory else {
      return []
    }

    var nodes: [TreeNode<Payload>] = []
    try await fileSystem.withDirectoryHandle(atPath: nodesDirectory) { directory in
      for try await entry in directory.listContents() {
        guard entry.type == .directory else { continue }
        let manifest = NodeStorage.manifestFile(in: entry.path)
        guard
          let fileInfo = try await fileSystem.info(forFileAt: manifest),
          fileInfo.type == .regular
        else {
          continue
        }
        let buffer = try await ByteBuffer(
          contentsOf: manifest,
          maximumSizeAllowed: .mebibytes(1),
          fileSystem: fileSystem
        )
        let node: TreeNode<Payload> = try NodeStorage.decode(from: Data(buffer.readableBytesView))
        nodes.append(node)
      }
    }
    return nodes
  }
}
