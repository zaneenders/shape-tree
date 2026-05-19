@testable import NodeTree
import Testing
import _NIOFileSystem

@Suite
struct NodeTreeStoreTests {

  @Test func openSeedsRootAndCreateNodePersists() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: ".node-tree",
        rootPayload: TitlePayload(title: "root")
      )
      let child = try await store.createNode(
        payload: TitlePayload(title: "write tests"),
        parentId: .root
      )

      let reloaded = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: ".node-tree",
        rootPayload: TitlePayload(title: "ignored on reload")
      )
      let reloadedRootID = await reloaded.rootID

      let ordered = try await reloaded.topologicalSort()
      #expect(ordered.map(\.id) == [reloadedRootID, child.id])
    }
  }

  @Test func openLoadsExistingOnDiskLayout() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: ".node-tree",
        rootPayload: TitlePayload(title: "root")
      )
      let rootID = await store.rootID
      let child = try await store.createNode(
        payload: TitlePayload(title: "write tests"),
        parentId: .root
      )

      let rootManifest = nodeManifest(at: path, dataDirectoryName: ".node-tree", id: rootID)
      let childManifest = nodeManifest(at: path, dataDirectoryName: ".node-tree", id: child.id)
      #expect(try await store.fileSystem.info(forFileAt: rootManifest)?.type == .regular)
      #expect(try await store.fileSystem.info(forFileAt: childManifest)?.type == .regular)

      let loaded = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: ".node-tree",
        rootPayload: TitlePayload(title: "ignored")
      )
      #expect(await loaded.rootID == rootID)
      #expect(try await loaded.root()?.payload.title == "root")
      #expect(try await loaded.node(id: child.id)?.payload.title == "write tests")
      #expect(try await loaded.topologicalSort().map(\.id) == [rootID, child.id])
    }
  }

  @Test func eachNodeHasOwnDirectoryOnDisk() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: ".node-tree",
        rootPayload: TitlePayload(title: "root")
      )
      let rootID = await store.rootID
      let child = try await store.createNode(
        payload: TitlePayload(title: "child"),
        parentId: .root
      )
      let dirName = store.dataDirectoryName
      let nodesDir = path.appending(dirName).appending("nodes")
      #expect(try await store.fileSystem.info(forFileAt: nodesDir)?.type == .directory)
      #expect(try await store.fileSystem.info(forFileAt: nodesDir.appending(rootID.description))?.type == .directory)
      #expect(try await store.fileSystem.info(forFileAt: nodesDir.appending(child.id.description))?.type == .directory)
    }
  }

  @Test func createNodeRequiresExistingParent() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: ".node-tree",
        rootPayload: TitlePayload(title: "root")
      )

      let missing = NodeID()
      await #expect(throws: NodeTreeError.parentNotFound(missing)) {
        try await store.createNode(payload: TitlePayload(title: "orphan"), parentId: .node(missing))
      }
    }
  }

  @Test func customDataDirectoryName() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: "todo-tree",
        rootPayload: TitlePayload(title: "root")
      )
      #expect(store.dataDirectoryName == "todo-tree")
      _ = try await store.createNode(payload: TitlePayload(title: "task"), parentId: .root)

      let nodesDir = path.appending("todo-tree").appending("nodes")
      #expect(try await store.fileSystem.info(forFileAt: nodesDir)?.type == .directory)
    }
  }

  @Test func multipleTreesCoexistInSameWorkspace() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let todo = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: "todo-tree",
        rootPayload: TitlePayload(title: "todos")
      )
      let context = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: ".context-tree",
        rootPayload: TitlePayload(title: "context")
      )

      let todoChild = try await todo.createNode(
        payload: TitlePayload(title: "write tests"),
        parentId: .root
      )
      let contextChild = try await context.createNode(
        payload: TitlePayload(title: "session"),
        parentId: .root
      )

      #expect(await todo.rootID != context.rootID)
      #expect(try await todo.node(id: contextChild.id) == nil)
      #expect(try await context.node(id: todoChild.id) == nil)
    }
  }

  @Test func repairsMultipleRootsWhenReopeningStore() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let dataDirectoryName = "todo-tree"
      let rootA = TreeNode(parentId: .root, payload: TitlePayload(title: "root-a"))
      let rootB = TreeNode(parentId: .root, payload: TitlePayload(title: "root-b"))
      let dataDirectory = path.appending(dataDirectoryName)
      let nodesDirectory = NodeStorage.nodesDirectory(in: dataDirectory)
      try await FileSystem.shared.createDirectory(at: nodesDirectory, withIntermediateDirectories: true)

      for node in [rootA, rootB] {
        let nodeDirectory = NodeStorage.nodeDirectory(in: nodesDirectory, id: node.id)
        try await FileSystem.shared.createDirectory(at: nodeDirectory, withIntermediateDirectories: true)
        let manifest = NodeStorage.manifestFile(in: nodeDirectory)
        let data = try NodeStorage.encode(node)
        try await FileSystem.shared.withFileHandle(
          forWritingAt: manifest,
          options: .newFile(replaceExisting: true)
        ) { handle in
          try await handle.write(contentsOf: data, toAbsoluteOffset: 0)
          try await handle.close()
        }
      }

      let store = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: dataDirectoryName,
        rootPayload: TitlePayload(title: "ignored")
      )
      let roots = try await store.topologicalSort().filter {
        if case .root = $0.parentId { return true }
        return false
      }
      #expect(roots.count == 1)
      let canonicalRootID = try await store.canonicalRootID()
      let reparented = try await store.node(id: rootA.id == canonicalRootID ? rootB.id : rootA.id)
      if case .node(let parent) = reparented?.parentId {
        #expect(parent == canonicalRootID)
      } else {
        Issue.record("Expected stray root to be reparented under canonical root")
      }
    }
  }

  @Test func rejectsInvalidDataDirectoryName() async throws {
    return try await FileSystem.shared.withTemporaryDirectory { _, path in
      await #expect(throws: NodeTreeError.invalidDataDirectoryName("nested/name")) {
        try await NodeTreeStore.open(
          root: path,
          dataDirectoryName: "nested/name",
          rootPayload: TitlePayload(title: "root")
        )
      }
    }
  }

  private func nodeManifest(at path: FilePath, dataDirectoryName: String, id: NodeID) -> FilePath {
    path.appending(dataDirectoryName).appending("nodes").appending(id.description).appending("node.json")
  }
}
