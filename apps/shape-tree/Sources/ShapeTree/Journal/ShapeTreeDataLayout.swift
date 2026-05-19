import Foundation
import ShapeTreeClient

/// Layout of mutable ShapeTree server data under a required server `data_path` root `R`.
///
/// All on-disk artifacts (journal git repo, trust store, NodeTree stores such as `todo-tree`) live
/// under `R/.shape-tree/`.
public struct ShapeTreeDataLayout: Sendable {

  public static let dotFolderName = ".shape-tree"
  public static let subjectsFileName = "journal-subjects.json"
  public static let journalDirectoryName = "Journal"
  public static let authorizedKeysDirectoryName = "authorized_keys"
  /// Default NodeTree store name for the todo HTTP API (`R/.shape-tree/todo-tree/`).
  public static let defaultTodoTreeName = "todo-tree"

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

  /// Trust store: `R/.shape-tree/authorized_keys/<thumbprint>.jwk`.
  public var authorizedKeysDirectory: URL {
    dotFolder.appendingPathComponent(Self.authorizedKeysDirectoryName, isDirectory: true)
  }

  /// Workspace root passed to ``NodeTreeStore`` (`R/.shape-tree/`).
  public var nodeTreeWorkspace: URL {
    dotFolder
  }

  public func nodeTreeDirectory(treeName: String) -> URL {
    dotFolder.appendingPathComponent(treeName, isDirectory: true)
  }

  public func journalEntryFile(for date: Date) -> URL {
    journalRepoRoot.appendingPathComponent(
      JournalPathCodec.relativeMarkdownPath(for: date),
      isDirectory: false
    )
  }

  /// Resolves the configured `data_path` string into an absolute directory URL.
  ///
  /// - Absolute paths (including tilde expansion) are used as-is.
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
