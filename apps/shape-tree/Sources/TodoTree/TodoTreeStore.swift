import Foundation
import NIOFS

/// TodoTree persistence and mutation API backed by the local file system.
public actor TodoTreeStore {
  private static let dotFolderName = ".todo-tree"
  private static let rootTitle = "root"

  public let root: FilePath
  public let fileSystem: FileSystem
  public private(set) var rootID: TodoNodeID

  private var graph = TodoTreeGraph()
  private var isPrepared = false

  public init(root: FilePath, fileSystem: FileSystem = .shared) {
    self.root = root
    self.fileSystem = fileSystem
    rootID = TodoNodeID()
  }

  /// Opens a workspace tree: ensures on-disk layout exists, loads nodes from `nodes/` when present,
  /// otherwise seeds the hard-coded root node.
  public static func open(
    root: FilePath,
    fileSystem: FileSystem = .shared
  ) async throws -> TodoTreeStore {
    let store = TodoTreeStore(root: root, fileSystem: fileSystem)
    try await store.prepareOnDisk()
    return store
  }

  /// Creates a todo node linked under `parentId` (use `.root` or `.node(rootID)` to branch from the root).
  public func createNode(title: String, parentId: ParentId) async throws -> TodoNode {
    try await prepareOnDisk()
    let node = try graph.insertNode(title: title, parentId: parentId)
    try await persistNode(node)
    return node
  }

  public func node(id: TodoNodeID) async throws -> TodoNode? {
    try await prepareOnDisk()
    return graph.node(id: id)
  }

  public func root() async throws -> TodoNode? {
    try await prepareOnDisk()
    return try graph.root()
  }

  /// Nodes in topological order: root first, then descendants.
  public func topologicalSort() async throws -> [TodoNode] {
    try await prepareOnDisk()
    return try graph.topologicalSort()
  }

  private var dataDirectory: NIOFilePath {
    NIOFilePath(root).appending(Self.dotFolderName)
  }

  private var nodesDirectory: NIOFilePath {
    TodoNodeStorage.nodesDirectory(in: dataDirectory)
  }

  private func prepareOnDisk() async throws {
    guard !isPrepared else { return }

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
      let root = try graph.seedRoot(title: Self.rootTitle)
      rootID = root.id
      try await persistNode(root)
    } else {
      rootID = try graph.rootID()
    }

    isPrepared = true
  }

  private func loadGraph() async throws -> TodoTreeGraph {
    let loader = TodoNodeDirectoryLoader(fileSystem: fileSystem)
    let nodes = try await loader.loadNodes(from: nodesDirectory)
    guard !nodes.isEmpty else { return TodoTreeGraph() }
    return try TodoTreeGraph(nodes: nodes)
  }

  private func persistNode(_ node: TodoNode) async throws {
    let nodeDirectory = TodoNodeStorage.nodeDirectory(in: nodesDirectory, id: node.id)
    try await fileSystem.createDirectory(
      at: nodeDirectory,
      withIntermediateDirectories: true
    )
    let manifest = TodoNodeStorage.manifestFile(in: nodeDirectory)
    let data = try TodoNodeStorage.encode(node)
    try await fileSystem.withFileHandle(
      forWritingAt: manifest,
      options: .newFile(replaceExisting: true)
    ) { handle in
      try await handle.write(contentsOf: data, toAbsoluteOffset: 0)
      try await handle.close()
    }
  }
}
