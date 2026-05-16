import Foundation
import Logging
import ShapeTreeClient
import Sit

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

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
    case .emptySubjects: "At least one subject id is required."
    case .utf8EncodingFailed: "Journal text is not valid UTF-8."
    case .emptySubjectLabel: "Subject label cannot be empty."
    case .invalidJournalDayKey: "journal_day must be a valid yy-MM-dd key."
    }
  }
}

public enum JournalQueryError: Error, Sendable, Equatable {
  case invalidJournalDayKey
  case invalidRange
}

/// Sole owner of the on-disk journal: subjects catalogue, append (git-managed),
/// per-day summaries, and per-day detail. Merges the previous `JournalService`
/// and `JournalQueryService` so callers wire one type instead of two.
public actor JournalStore {

  public struct Summary: Sendable {
    public let dateKey: String
    public let journalRelativePath: String
    public let wordCount: Int
    public let lineCount: Int
  }

  public struct Detail: Sendable {
    public let dateKey: String
    public let journalRelativePath: String
    public let content: String
    public let wordCount: Int
    public let lineCount: Int
  }

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

  // MARK: - Git bootstrap

  /// Runs ``git init`` inside `Journal/` when `.git` is missing; the initial commit happens on first append.
  public func initializeJournalGitRepoIfNeeded() async throws {
    let cwd = FilePath(layout.journalRepoRoot.path)
    try await sit.initializeRepoIfNeeded(cwd: cwd, log: log)
    try await sit.ensureCommitAuthorIfUnset(
      cwd: cwd,
      log: log,
      fallbackCommitName: fallbackCommitAuthorName,
      fallbackCommitEmail: fallbackCommitAuthorEmail)
  }

  // MARK: - Subjects

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

  // MARK: - Append

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

    let block = [
      "# \(heading)",
      "",
      body.trimmingCharacters(in: .whitespacesAndNewlines),
      "",
      "-----",
      "",
    ].joined(separator: "\n")

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
    try fileManager.createDirectory(at: entryURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let cwd = FilePath(layout.journalRepoRoot.path)
    try await sit.pullRebaseIfClean(cwd: cwd, log: log)

    var combined: String
    if fileManager.fileExists(atPath: entryURL.path),
      let existing = try? String(contentsOf: entryURL, encoding: .utf8)
    {
      combined = existing
      if !combined.hasSuffix("\n") { combined.append("\n") }
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

  // MARK: - Read (formerly JournalQueryService)

  /// Lists summaries for every calendar day in `[startDayKey, endDayKey]` (inclusive) that has an on-disk entry.
  public func listSummaries(startDayKey: String, endDayKey: String) throws -> [Summary] {
    guard
      let start = JournalPathCodec.date(fromJournalDayKey: startDayKey),
      let end = JournalPathCodec.date(fromJournalDayKey: endDayKey)
    else { throw JournalQueryError.invalidJournalDayKey }
    guard start <= end else { throw JournalQueryError.invalidRange }

    let calendar = JournalPathCodec.utcCalendar
    var out: [Summary] = []
    var cursor = start

    while cursor <= end {
      let dayKey = JournalPathCodec.journalDayKey(for: cursor, calendar: calendar)
      let relativePath = JournalPathCodec.relativeMarkdownPath(for: cursor, calendar: calendar)
      let url = layout.journalRepoRoot.appendingPathComponent(relativePath, isDirectory: false)

      if fileManager.fileExists(atPath: url.path),
        let raw = try? String(contentsOf: url, encoding: .utf8)
      {
        let counts = Self.wordAndLineCounts(raw)
        out.append(
          Summary(
            dateKey: dayKey,
            journalRelativePath: relativePath,
            wordCount: counts.words,
            lineCount: counts.lines))
      }

      guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = next
    }

    log.debug(
      "event=journal.query.list",
      metadata: [
        "start": .string(startDayKey),
        "end": .string(endDayKey),
        "hits": .stringConvertible(out.count),
      ])

    return out.sorted { $0.dateKey > $1.dateKey }
  }

  /// Loads full Markdown for `yy-MM-dd`, or nil when missing.
  public func entryDetail(dayKey: String) throws -> Detail? {
    guard let date = JournalPathCodec.date(fromJournalDayKey: dayKey) else {
      throw JournalQueryError.invalidJournalDayKey
    }

    let relativePath = JournalPathCodec.relativeMarkdownPath(for: date)
    let url = layout.journalRepoRoot.appendingPathComponent(relativePath, isDirectory: false)
    guard fileManager.fileExists(atPath: url.path) else { return nil }

    let raw = try String(contentsOf: url, encoding: .utf8)
    let counts = Self.wordAndLineCounts(raw)
    return Detail(
      dateKey: dayKey,
      journalRelativePath: relativePath,
      content: raw,
      wordCount: counts.words,
      lineCount: counts.lines)
  }

  // MARK: - Internals

  nonisolated private static func wordAndLineCounts(_ content: String) -> (words: Int, lines: Int) {
    let lineCount = content.components(separatedBy: .newlines).count
    let wordCount =
      content
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .count
    return (wordCount, lineCount)
  }

  nonisolated private static func writeSubjectsFile(
    _ file: JournalSubjectsFile,
    to url: URL,
    fileManager: FileManager
  ) throws {
    let data = try file.encodedForSubjectsFile()
    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }

  nonisolated private static func makeUniqueSubjectId(for label: String, existingIds: Set<String>) -> String {
    var base = deriveBaseId(from: label)
    if base.isEmpty { base = "subject" }
    if !existingIds.contains(base) { return base }
    var n = 2
    while existingIds.contains("\(base)-\(n)") { n += 1 }
    return "\(base)-\(n)"
  }

  nonisolated private static func deriveBaseId(from label: String) -> String {
    let normalized = label
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
    if slug.isEmpty { return fallbackSubjectIdDigest(normalized) }

    let sanitized = JournalPathCodec.sanitizeFilenameComponent(slug).lowercased()
    if sanitized.isEmpty || sanitized == "unknown-device" {
      return fallbackSubjectIdDigest(normalized)
    }
    return sanitized
  }

  /// Stable, filename-safe token when the label does not slugify (e.g. emoji-only).
  nonisolated private static func fallbackSubjectIdDigest(_ normalizedLabel: String) -> String {
    let hash = SHA256.hash(data: Data(normalizedLabel.utf8))
    let hex = hash.prefix(6).map { String(format: "%02x", $0) }.joined()
    return "s-\(hex)"
  }
}
