import Foundation
import Logging
import Sit
import Testing

#if canImport(System)
import System
#else
import SystemPackage
#endif

@Suite
struct SitSmokeTests {

  @Test func initializesEmptyGitRepositoryWithoutCommits() async throws {
    let log = Logger(label: "sit.smoke-tests")
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let cwd = FilePath(root.path)
    let sit = Sit()

    try await sit.initializeRepoIfNeeded(cwd: cwd, log: log)

    let gitDir = root.appendingPathComponent(".git", isDirectory: true)
    #expect(fm.fileExists(atPath: gitDir.path))

    #expect(!(try await sit.isCleanIndexedAndTracked(cwd: cwd, log: log)))
  }
}
