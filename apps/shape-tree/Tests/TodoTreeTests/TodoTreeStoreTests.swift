import NIOFS
import Testing
import TodoTree

@Suite
struct TodoTreeStoreTests {

  @Test func openSeedsRootAndCreateNodePersists() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await TodoTreeStore.open(root: FilePath(path))
      let child = try await store.createNode(title: "write tests", parentId: .root)

      let reloaded = try await TodoTreeStore.open(root: FilePath(path))
      let reloadedRootID = await reloaded.rootID

      let ordered = try await reloaded.topologicalSort()
      #expect(ordered.map(\.id) == [reloadedRootID, child.id])
    }
  }

  @Test func openLoadsExistingOnDiskLayout() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await TodoTreeStore.open(root: FilePath(path))
      let rootID = await store.rootID
      let child = try await store.createNode(title: "write tests", parentId: .root)

      let rootManifest = nodeManifest(at: path, id: rootID)
      let childManifest = nodeManifest(at: path, id: child.id)
      #expect(try await store.fileSystem.info(forFileAt: rootManifest)?.type == .regular)
      #expect(try await store.fileSystem.info(forFileAt: childManifest)?.type == .regular)

      let loaded = try await TodoTreeStore.open(root: FilePath(path))
      #expect(await loaded.rootID == rootID)
      #expect(try await loaded.root()?.title == "root")
      #expect(try await loaded.node(id: child.id)?.title == "write tests")
      #expect(try await loaded.topologicalSort().map(\.id) == [rootID, child.id])
    }
  }

  @Test func eachNodeHasOwnDirectoryOnDisk() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await TodoTreeStore.open(root: FilePath(path))
      let rootID = await store.rootID
      let child = try await store.createNode(title: "child", parentId: .root)

      let nodesDir = NIOFilePath(FilePath(path)).appending(".todo-tree").appending("nodes")
      #expect(try await store.fileSystem.info(forFileAt: nodesDir)?.type == .directory)
      #expect(try await store.fileSystem.info(forFileAt: nodesDir.appending(rootID.description))?.type == .directory)
      #expect(try await store.fileSystem.info(forFileAt: nodesDir.appending(child.id.description))?.type == .directory)
    }
  }

  @Test func createNodeRequiresExistingParent() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await TodoTreeStore.open(root: FilePath(path))

      let missing = TodoNodeID()
      await #expect(throws: TodoTreeError.parentNotFound(missing)) {
        try await store.createNode(title: "orphan", parentId: .node(missing))
      }
    }
  }

  private func nodeManifest(at path: NIOFilePath, id: TodoNodeID) -> NIOFilePath {
    path.appending(".todo-tree").appending("nodes").appending(id.description).appending("node.json")
  }
}
