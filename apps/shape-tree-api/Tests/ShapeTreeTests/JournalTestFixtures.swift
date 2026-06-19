import Foundation
import Logging
import ShapeTree

enum JournalTestFixtures {

  /// Fresh `JournalStore` rooted in `NSTemporaryDirectory` with git bootstrapped.
  static func ephemeralJournalWorkspace(log: Logger) async throws -> (JournalStore, ShapeTreeDataLayout) {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let layout = ShapeTreeDataLayout(dataRoot: root)
    try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)

    let store = JournalStore(layout: layout, log: log)
    try await store.initializeJournalGitRepoIfNeeded()
    return (store, layout)
  }
}
