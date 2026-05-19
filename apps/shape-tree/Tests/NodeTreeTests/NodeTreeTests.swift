import NodeTree
import Testing
import _NIOFileSystem

@Suite
struct NodeTreeTests {

  @Test func openSeedsRootOnDisk() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await NodeTreeStore.open(
        root: path,
        dataDirectoryName: ".node-tree",
        rootPayload: TitlePayload(title: "root")
      )
      #expect(try await store.root()?.payload.title == "root")
    }
  }
}
