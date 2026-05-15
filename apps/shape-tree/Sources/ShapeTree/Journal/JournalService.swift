#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation
import Logging
import Sit

#if canImport(System)
import System
#else
import SystemPackage
#endif

public enum JournalServiceError: Error, Sendable, CustomStringConvertible {
  case emptySubjects
  case utf8EncodingFailed
  case emptySubjectLabel
  case invalidJournalDayKey

  public var description: String {
    switch self {
    case .emptySubjects:
      "At least one subject id is required."
    case .utf8EncodingFailed:
      "Journal text is not valid UTF-8."
    case .emptySubjectLabel:
      "Subject label cannot be empty."
    case .invalidJournalDayKey:
      "journal_day must be a valid yy-MM-dd key."
    }
  }
}

/// Local journal append + subject listing; git operations go through ``Sit`` at the journal repo root.
public actor JournalService {

  private let layout: ShapeTreeDataLayout
  private let sit: Sit
  private let log: Logger
  private let fileManager: FileManager
  private let fallbackCommitAuthorName: String
  private let fallbackCommitAuthorEmail: String

  public init(
    layout: ShapeTreeDataLayout,
    sit: Sit = Sit(),
    log: Logger,
    fileManager: FileManager = .default,
    fallbackCommitAuthorName: String = "ShapeTree",
    fallbackCommitAuthorEmail: String = "shape-tree@localhost"
  ) {
    self.layout = layout
    self.sit = sit
    self.log = log
    self.fileManager = fileManager
    self.fallbackCommitAuthorName = fallbackCommitAuthorName
    self.fallbackCommitAuthorEmail = fallbackCommitAuthorEmail
  }

  /// Runs ``git init`` inside `Journal/` when `.git` is missing.
  ///
  /// The initial commit happens on the **first appended entry** (Scribe-aligned); there is no placeholder file.
  public func initializeJournalGitRepoIfNeeded() async throws {
    let cwd = FilePath(layout.journalRepoRoot.path)
    try await sit.initializeRepoIfNeeded(cwd: cwd, log: log)
    try await sit.ensureCommitAuthorIfUnset(
      cwd: cwd,
      log: log,
      fallbackCommitName: fallbackCommitAuthorName,
      fallbackCommitEmail: fallbackCommitAuthorEmail)
  }

  public func loadSubjects() throws -> JournalSubjectsFile {
    let data = try Data(contentsOf: layout.journalSubjectsFile)
    return try JSONDecoder().decode(JournalSubjectsFile.self, from: data)
  }

  /// Adds a subject when no existing row has the same label (case-insensitive). Otherwise returns the file unchanged.
  public func appendSubject(rawLabel: String) throws -> JournalSubjectsFile {
    let label = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !label.isEmpty else {
      throw JournalServiceError.emptySubjectLabel
    }

    var file = try loadSubjects()
    if file.subjects.contains(where: { $0.label.caseInsensitiveCompare(label) == .orderedSame }) {
      return file
    }

    let usedIds = Set(file.subjects.map(\.id))
    let newId = Self.makeUniqueSubjectId(for: label, existingIds: usedIds)
    file.subjects.append(JournalSubjectsFile.Subject(id: newId, label: label))
    try Self.writeSubjectsFile(file, to: layout.journalSubjectsFile, fileManager: fileManager)
    log.info("event=journal.subject.append id=\(newId) label=\(label)")
    return file
  }

  public func appendEntry(
    subjectIds: [String],
    body: String,
    createdAt: Date?,
    journalDayKey: String?
  ) async throws -> String {
    guard !subjectIds.isEmpty else {
      throw JournalServiceError.emptySubjects
    }

    let subjects = try loadSubjects()
    let lookup = Dictionary(uniqueKeysWithValues: subjects.subjects.map { ($0.id, $0.label) })
    let labels = subjectIds.map { lookup[$0] ?? $0 }
    let heading = labels.joined(separator: ", ")

    let now = Date()
    let rawCreated = createdAt ?? now
    // Never persist a stamp or filing day in the future (bad clients / clock skew).
    let created = rawCreated <= now ? rawCreated : now

    let blockLines = [
      "# \(heading)",
      "",
      body.trimmingCharacters(in: .whitespacesAndNewlines),
      "",
      "-----",
      "",
    ]
    let block = blockLines.joined(separator: "\n")

    let filingDate: Date
    if let journalDayKey {
      let trimmed = journalDayKey.trimmingCharacters(in: .whitespacesAndNewlines)
      guard let d = JournalPathCodec.date(fromJournalDayKey: trimmed) else {
        throw JournalServiceError.invalidJournalDayKey
      }
      filingDate = d
    } else {
      filingDate = created
    }

    let relativePath = JournalPathCodec.relativeMarkdownPath(for: filingDate)
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

  private static func writeSubjectsFile(
    _ file: JournalSubjectsFile,
    to url: URL,
    fileManager: FileManager
  ) throws {
    let data = try file.encodedForSubjectsFile()
    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
  }

  private static func makeUniqueSubjectId(for label: String, existingIds: Set<String>) -> String {
    var base = deriveBaseId(from: label)
    if base.isEmpty {
      base = "subject"
    }
    if !existingIds.contains(base) {
      return base
    }
    var n = 2
    while existingIds.contains("\(base)-\(n)") {
      n += 1
    }
    return "\(base)-\(n)"
  }

  private static func deriveBaseId(from label: String) -> String {
    let normalized =
      label
      .precomposedStringWithCanonicalMapping
      .trimmingCharacters(in: .whitespacesAndNewlines)

    var slug = ""
    slug.reserveCapacity(normalized.count)
    for ch in normalized {
      if ch.isLetter || ch.isNumber {
        slug.append(contentsOf: String(ch).lowercased())
      } else if ch.isWhitespace || ch == "-" || ch == "_" {
        slug.append("-")
      } else {
        slug.append("-")
      }
    }
    while slug.contains("--") {
      slug = slug.replacingOccurrences(of: "--", with: "-")
    }
    slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    if slug.isEmpty {
      return fallbackSubjectIdDigest(normalized)
    }
    let sanitized = JournalPathCodec.sanitizeFilenameComponent(slug).lowercased()
    if sanitized.isEmpty || sanitized == "unknown-device" {
      return fallbackSubjectIdDigest(normalized)
    }
    return sanitized
  }

  /// Stable, filename-safe token when the label does not slugify (e.g. emoji-only).
  private static func fallbackSubjectIdDigest(_ normalizedLabel: String) -> String {
    let hash = SHA256.hash(data: Data(normalizedLabel.utf8))
    let hex = hash.prefix(6).map { String(format: "%02x", $0) }.joined()
    return "s-\(hex)"
  }
}
