import Foundation
import ShapeTree
import Testing

@Suite struct ShapeTreePathsTests {

  @Test func utcJournalMarkdownRelativePath() throws {
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 5
    comps.day = 6

    let date = try #require(JournalPathCodec.utcCalendar.date(from: comps))
    let path = JournalPathCodec.relativeMarkdownPath(for: date)
    #expect(path == "26/05/26-05-06.md")
  }

  @Test func resolvesAbsoluteSlashPathIgnoringCwd() {
    let bogusCwd = URL(fileURLWithPath: "/bogus/cwd")

    let absolute = ShapeTreeDataLayout.resolveDataRoot(rawPath: "/var/shape-tree", cwd: bogusCwd)
    #expect(absolute.path == "/var/shape-tree")
  }

  @Test func resolvesRelativePathAgainstCWD() throws {
    let fm = FileManager.default
    let sandbox = fm.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("sandbox", isDirectory: true)
    try fm.createDirectory(at: sandbox, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: sandbox) }

    let leaf = UUID().uuidString
    let resolved = ShapeTreeDataLayout.resolveDataRoot(rawPath: leaf, cwd: sandbox)

    #expect(resolved.lastPathComponent == leaf)
    #expect(resolved.deletingLastPathComponent().standardizedFileURL == sandbox.standardizedFileURL)
  }

  @Test func sanitizeDeviceFilename() {
    #expect(JournalPathCodec.sanitizeFilenameComponent("My Device!") == "My-Device-")
    #expect(JournalPathCodec.sanitizeFilenameComponent(" ") == "unknown-device")
    #expect(JournalPathCodec.sanitizeFilenameComponent("ok_id.v2") == "ok_id.v2")
  }
}
