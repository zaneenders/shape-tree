import Testing
import TodoTree
import _NIOFileSystem

@Suite
struct TodoTreeTests {
  @Test func bootstrapCreatesDataDirectory() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let layout = TodoTreeLayout(root: path)
      let store = TodoTreeStore(layout: layout)
      try await store.bootstrapIfNeeded()
      if let info = try await store.fileSystem.info(forFileAt: layout.dataDirectory) {
        print(String(describing: info))
        #expect(info.type == .directory)
      } else {
        Issue.record("Could not create directory")
      }
    }
  }
}
