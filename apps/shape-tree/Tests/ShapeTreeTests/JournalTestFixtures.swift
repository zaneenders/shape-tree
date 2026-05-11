import Foundation
import Logging
import ShapeTree

enum JournalTestFixtures {

  /// Fresh `JournalService` rooted in `NSTemporaryDirectory` with git bootstrapped.
  static func ephemeralJournalWorkspace(log: Logger) async throws -> (JournalService, ShapeTreeDataLayout) {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let layout = ShapeTreeDataLayout(dataRoot: root)
    try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)

    let svc = JournalService(layout: layout, log: log)
    try await svc.initializeJournalGitRepoIfNeeded()
    return (svc, layout)
  }
}
