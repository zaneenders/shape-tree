import Foundation
import _NIOFileSystem

/// Persistent payload tree backed by the local file system.
public actor NodeTreeStore<Payload: Codable & Sendable> {
  public let root: FilePath
  /// Dot-directory under ``root`` (e.g. `.todo-tree`, `.context-tree`).
  public nonisolated let dataDirectoryName: String
  public let fileSystem: FileSystem
  public private(set) var rootID: NodeID

  private var graph = NodeTreeGraph<Payload>()
  private var isPrepared = false
  private let rootPayload: Payload

  public init(
    root: FilePath,
    dataDirectoryName: String,
    rootPayload: Payload,
    fileSystem: FileSystem = .shared
  ) {
    self.root = root
    self.dataDirectoryName = dataDirectoryName
    self.rootPayload = rootPayload
    self.fileSystem = fileSystem
    rootID = NodeID()
  }

  /// Opens a workspace tree: ensures on-disk layout exists, loads nodes from `nodes/` when present,
  /// otherwise seeds the root with `rootPayload`.
  public static func open(
    root: FilePath,
    dataDirectoryName: String,
    rootPayload: Payload,
    fileSystem: FileSystem = .shared
  ) async throws -> NodeTreeStore<Payload> {
    try validateDataDirectoryName(dataDirectoryName)
    let store = NodeTreeStore(
      root: root,
      dataDirectoryName: dataDirectoryName,
      rootPayload: rootPayload,
      fileSystem: fileSystem
    )
    try await store.prepareOnDisk()
    return store
  }

  /// Creates a node linked under `parentId` (use `.root` or `.node(rootID)` to branch from the root).
  public func createNode(payload: Payload, parentId: ParentId) async throws -> TreeNode<Payload> {
    try await prepareOnDisk()
    let node = try graph.insertNode(payload: payload, parentId: parentId)
    try await persistNode(node)
    return node
  }

  public func node(id: NodeID) async throws -> TreeNode<Payload>? {
    try await prepareOnDisk()
    return graph.node(id: id)
  }

  public func root() async throws -> TreeNode<Payload>? {
    try await prepareOnDisk()
    return try graph.root()
  }

  /// Nodes in topological order: root first, then descendants.
  public func topologicalSort() async throws -> [TreeNode<Payload>] {
    try await prepareOnDisk()
    return try graph.topologicalSort()
  }

  private var dataDirectory: FilePath {
    root.appending(dataDirectoryName)
  }

  private var nodesDirectory: FilePath {
    NodeStorage.nodesDirectory(in: dataDirectory)
  }

  private func prepareOnDisk() async throws {
    guard !isPrepared else { return }
    try Self.validateDataDirectoryName(dataDirectoryName)

    try await fileSystem.createDirectory(
      at: dataDirectory,
      withIntermediateDirectories: true
    )
    try await fileSystem.createDirectory(
      at: nodesDirectory,
      withIntermediateDirectories: true
    )

    graph = try await loadGraph()
    if graph.isEmpty {
      let root = try graph.seedRoot(payload: rootPayload)
      rootID = root.id
      try await persistNode(root)
    } else {
      rootID = try graph.rootID()
    }

    isPrepared = true
  }

  private func loadGraph() async throws -> NodeTreeGraph<Payload> {
    let loader = NodeDirectoryLoader<Payload>(fileSystem: fileSystem)
    let nodes = try await loader.loadNodes(from: nodesDirectory)
    guard !nodes.isEmpty else { return NodeTreeGraph() }
    return try NodeTreeGraph(nodes: nodes)
  }

  private func persistNode(_ node: TreeNode<Payload>) async throws {
    let nodeDirectory = NodeStorage.nodeDirectory(in: nodesDirectory, id: node.id)
    try await fileSystem.createDirectory(
      at: nodeDirectory,
      withIntermediateDirectories: true
    )
    let manifest = NodeStorage.manifestFile(in: nodeDirectory)
    let data = try NodeStorage.encode(node)
    try await fileSystem.withFileHandle(
      forWritingAt: manifest,
      options: .newFile(replaceExisting: true)
    ) { handle in
      try await handle.write(contentsOf: data, toAbsoluteOffset: 0)
      try await handle.close()
    }
  }

  private static func validateDataDirectoryName(_ name: String) throws {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != ".", trimmed != ".." else {
      throw NodeTreeError.invalidDataDirectoryName(name)
    }
    guard !trimmed.contains("/"), !trimmed.contains("\\") else {
      throw NodeTreeError.invalidDataDirectoryName(name)
    }
  }
}
