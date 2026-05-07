#if canImport(System)
import System
#else
import SystemPackage
#endif
import Foundation
import Logging
import Sit

public enum JournalServiceError: Error, Sendable, CustomStringConvertible {
  case emptySubjects
  case utf8EncodingFailed

  public var description: String {
    switch self {
    case .emptySubjects:
      "At least one subject id is required."
    case .utf8EncodingFailed:
      "Journal text is not valid UTF-8."
    }
  }
}

/// Local journal append + subject listing; git operations go through ``Sit`` at the journal repo root.
public actor JournalService {

  private let layout: ShapeTreeDataLayout
  private let sit: Sit
  private let log: Logger
  private let fileManager: FileManager

  public init(
    layout: ShapeTreeDataLayout,
    sit: Sit = Sit(),
    log: Logger,
    fileManager: FileManager = .default
  ) {
    self.layout = layout
    self.sit = sit
    self.log = log
    self.fileManager = fileManager
  }

  /// Runs ``git init`` inside `Journal/` when `.git` is missing.
  ///
  /// The initial commit happens on the **first appended entry** (Scribe-aligned); there is no placeholder file.
  public func initializeJournalGitRepoIfNeeded() async throws {
    let cwd = FilePath(layout.journalRepoRoot.path)
    try await sit.initializeRepoIfNeeded(cwd: cwd, log: log)
  }

  public func loadSubjects() throws -> JournalSubjectsFile {
    let data = try Data(contentsOf: layout.journalSubjectsFile)
    return try JSONDecoder().decode(JournalSubjectsFile.self, from: data)
  }

  public func appendEntry(
    subjectIds: [String],
    body: String,
    createdAt: Date?
  ) async throws -> String {
    guard !subjectIds.isEmpty else {
      throw JournalServiceError.emptySubjects
    }

    let subjects = try loadSubjects()
    let lookup = Dictionary(uniqueKeysWithValues: subjects.subjects.map { ($0.id, $0.label) })
    let labels = subjectIds.map { lookup[$0] ?? $0 }
    let heading = labels.joined(separator: ", ")

    let created = createdAt ?? Date()
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]

    let blockLines = [
      "# \(heading)",
      iso.string(from: created),
      "",
      body.trimmingCharacters(in: .whitespacesAndNewlines),
      "",
      "-----",
      "",
    ]
    let block = blockLines.joined(separator: "\n")

    let relativePath = JournalPathCodec.relativeMarkdownPath(for: created)
    let entryURL = layout.journalRepoRoot.appendingPathComponent(relativePath, isDirectory: false)
    let parent = entryURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

    let cwd = FilePath(layout.journalRepoRoot.path)
    try await sit.pullRebaseIfClean(cwd: cwd, log: log)

    var combined: String
    if fileManager.fileExists(atPath: entryURL.path),
      let existing = try? String(contentsOf: entryURL, encoding: .utf8)
    {
      combined = existing
      if !combined.hasSuffix("\n") {
        combined.append("\n")
      }
      combined.append("\n")
      combined.append(block)
    } else {
      combined = block
    }

    guard let data = combined.data(using: .utf8) else {
      throw JournalServiceError.utf8EncodingFailed
    }
    try data.write(to: entryURL, options: .atomic)

    try await sit.addCommitPush(
      cwd: cwd,
      relativePaths: [relativePath],
      message: "journal: append entry",
      log: log)

    log.info(
      "event=journal.append path=\(relativePath) subjects=\(subjectIds.joined(separator: ","))")

    return relativePath
  }

  public func persistDeviceRegistration(deviceToken: String, deviceId: String?) throws {
    let record = PersistedDeviceRecord(deviceToken: deviceToken, deviceId: deviceId)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let storageKey = deviceId ?? UUID().uuidString
    let url = layout.deviceRegistrationFile(deviceId: storageKey)
    let data = try encoder.encode(record)
    try data.write(to: url, options: .atomic)
    log.info("event=device.register path=\(url.lastPathComponent)")
  }

  private struct PersistedDeviceRecord: Encodable {
    let deviceToken: String
    let deviceId: String?
  }
}
