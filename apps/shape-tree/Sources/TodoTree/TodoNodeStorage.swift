import Foundation
import NIOCore
import NIOFS

extension NIOFilePath {
  package func appending(_ component: String) -> NIOFilePath {
    NIOFilePath(FilePath(self).appending(component))
  }
}

/// On-disk paths and encoding for a single todo node under `.todo-tree/nodes/<id>/`.
enum TodoNodeStorage {
  static let nodesDirectoryName = "nodes"
  static let manifestFileName = "node.json"

  static func nodesDirectory(in dataDirectory: NIOFilePath) -> NIOFilePath {
    dataDirectory.appending(nodesDirectoryName)
  }

  static func nodeDirectory(in nodesDirectory: NIOFilePath, id: TodoNodeID) -> NIOFilePath {
    nodesDirectory.appending(id.description)
  }

  static func manifestFile(in nodeDirectory: NIOFilePath) -> NIOFilePath {
    nodeDirectory.appending(manifestFileName)
  }

  static func encode(_ node: TodoNode) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(node)
  }

  static func decode(from data: Data) throws -> TodoNode {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(TodoNode.self, from: data)
  }
}

struct TodoNodeDirectoryLoader: Sendable {
  let fileSystem: FileSystem

  func loadNodes(from nodesDirectory: NIOFilePath) async throws -> [TodoNode] {
    guard let info = try await fileSystem.info(forFileAt: nodesDirectory), info.type == .directory else {
      return []
    }

    var nodes: [TodoNode] = []
    try await fileSystem.withDirectoryHandle(atPath: nodesDirectory) { directory in
      for try await entry in directory.listContents() {
        guard entry.type == .directory else { continue }
        let manifest = TodoNodeStorage.manifestFile(in: entry.path)
        guard
          let fileInfo = try await fileSystem.info(forFileAt: manifest),
          fileInfo.type == .regular
        else {
          continue
        }
        let buffer = try await ByteBuffer(
          contentsOf: manifest,
          maximumSizeAllowed: .mebibytes(1)
        )
        let node = try TodoNodeStorage.decode(from: Data(buffer.readableBytesView))
        nodes.append(node)
      }
    }
    return nodes
  }
}
