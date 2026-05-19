import NIOFS
import Testing
import TodoTree

@Suite
struct TodoTreeTests {
  @Test func openSeedsRootOnDisk() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let store = try await TodoTreeStore.open(root: FilePath(path))
      #expect(try await store.root()?.title == "root")
    }
  }
}
