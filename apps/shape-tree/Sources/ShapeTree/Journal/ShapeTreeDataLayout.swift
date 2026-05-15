import Foundation

/// Layout of Scribe‑compatible mutable data under a required server `data_path` root `R`.
///
/// All journal and local device metadata live under `R/.shape-tree/` (dot folder name is fixed for this server).
public struct ShapeTreeDataLayout: Sendable {

  public static let dotFolderName = ".shape-tree"
  public static let subjectsFileName = "journal-subjects.json"
  public static let journalDirectoryName = "Journal"
  public static let authorizedKeysDirectoryName = "authorized_keys"

  public let dataRoot: URL

  public init(dataRoot: URL) {
    self.dataRoot = dataRoot.standardizedFileURL
  }

  public var dotFolder: URL {
    dataRoot.appendingPathComponent(Self.dotFolderName, isDirectory: true)
  }

  public var journalRepoRoot: URL {
    dotFolder.appendingPathComponent(Self.journalDirectoryName, isDirectory: true)
  }

  public var journalSubjectsFile: URL {
    dotFolder.appendingPathComponent(Self.subjectsFileName, isDirectory: false)
  }

  /// SSH-`authorized_keys`-style trust store: `R/.shape-tree/authorized_keys/<thumbprint>.jwk` (auth.md).
  public var authorizedKeysDirectory: URL {
    dotFolder.appendingPathComponent(Self.authorizedKeysDirectoryName, isDirectory: true)
  }

  public func journalEntryFile(for date: Date) -> URL {
    journalRepoRoot.appendingPathComponent(
      JournalPathCodec.relativeMarkdownPath(for: date),
      isDirectory: false
    )
  }

  /// Resolves the configured `data_path` string into an absolute directory URL.
  ///
  /// - Absolute paths (including tilde expansion) are used as‑is.
  /// - Relative paths (including `.`) resolve against `cwd` — typically the server process working directory at startup.
  public static func resolveDataRoot(rawPath: String, cwd: URL) -> URL {
    let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
    let expanded = (trimmed as NSString).expandingTildeInPath

    if expanded.hasPrefix("/") {
      return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    }

    return URL(fileURLWithPath: expanded, relativeTo: cwd.standardizedFileURL)
      .standardizedFileURL
  }

  /// Ensures dot folder, journal directory, and subjects JSON exist (`git init` happens from ``JournalService``).
  public static func bootstrapIfNeeded(
    layout: ShapeTreeDataLayout,
    fileManager: FileManager = .default
  ) throws {
    try fileManager.createDirectory(
      at: layout.dotFolder,
      withIntermediateDirectories: true)

    try fileManager.createDirectory(
      at: layout.journalRepoRoot,
      withIntermediateDirectories: true)

    try fileManager.createDirectory(
      at: layout.authorizedKeysDirectory,
      withIntermediateDirectories: true)

    if !fileManager.fileExists(atPath: layout.journalSubjectsFile.path) {
      let data = try JournalSubjectsFile.defaultTemplate.encodedForSubjectsFile()
      try data.write(to: layout.journalSubjectsFile, options: .atomic)

    }
  }
}

// MARK: - Journal path + subjects

public enum JournalPathCodec: Sendable {

  public static var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  /// Scribe layout: `yy/MM/yy-MM-dd.md` under the journal git root.
  public static func relativeMarkdownPath(for date: Date, calendar: Calendar = JournalPathCodec.utcCalendar) -> String {
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    let yy = year % 100
    return String(format: "%02d/%02d/%02d-%02d-%02d.md", yy, month, yy, month, day)
  }

  /// Two‑digit journal day key `yy-MM-dd` (Gregorian civil date components from the given calendar).
  public static func journalDayKey(for date: Date, calendar: Calendar = utcCalendar) -> String {
    let year = calendar.component(.year, from: date)
    let yy = year % 100
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    return String(format: "%02d-%02d-%02d", yy, month, day)
  }

  /// Parses `yy-MM-dd` into midnight on that civil day using `calendar` (defaults to stable UTC for key iteration).
  public static func date(fromJournalDayKey key: String, calendar: Calendar = utcCalendar) -> Date? {
    let parts = key.split(separator: "-")
    guard parts.count == 3,
      let yy = Int(parts[0]),
      let mm = Int(parts[1]),
      let dd = Int(parts[2]),
      (0...99).contains(yy),
      (1...12).contains(mm),
      (1...31).contains(dd)
    else { return nil }

    var comps = DateComponents()
    comps.calendar = calendar
    comps.timeZone = calendar.timeZone
    comps.year = 2000 + yy
    comps.month = mm
    comps.day = dd
    return calendar.date(from: comps)
  }

  public static func sanitizeFilenameComponent(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "unknown-device"
    }
    var out = ""
    out.reserveCapacity(trimmed.count)
    for ch in trimmed {
      if ch.isLetter || ch.isNumber || "-_.".contains(ch) {
        out.append(ch)
      } else {
        out.append("-")
      }
    }
    return out
  }
}

public struct JournalSubjectsFile: Codable, Sendable, Equatable {
  public var subjects: [Subject]

  public struct Subject: Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var label: String

    public init(id: String, label: String) {
      self.id = id
      self.label = label
    }
  }

  public init(subjects: [Subject]) {
    self.subjects = subjects
  }

  public static let defaultTemplate = JournalSubjectsFile(
    subjects: [Subject(id: "general", label: "General")]
  )

  /// On-disk JSON for `journal-subjects.json` (sorted keys, pretty-printed).
  public func encodedForSubjectsFile() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    return try encoder.encode(self)
  }
}
