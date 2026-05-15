import Foundation
import Logging

/// Reads journal Markdown laid out as ``JournalPathCodec/relativeMarkdownPath(for:)`` under ``ShapeTreeDataLayout/journalRepoRoot``.
public struct JournalQueryService: Sendable {

  public struct Summary: Sendable {
    public let dateKey: String
    public let journalRelativePath: String
    public let wordCount: Int
    public let lineCount: Int

    public init(dateKey: String, journalRelativePath: String, wordCount: Int, lineCount: Int) {
      self.dateKey = dateKey
      self.journalRelativePath = journalRelativePath
      self.wordCount = wordCount
      self.lineCount = lineCount
    }
  }

  public struct Detail: Sendable {
    public let dateKey: String
    public let journalRelativePath: String
    public let content: String
    public let wordCount: Int
    public let lineCount: Int

    public init(
      dateKey: String,
      journalRelativePath: String,
      content: String,
      wordCount: Int,
      lineCount: Int
    ) {
      self.dateKey = dateKey
      self.journalRelativePath = journalRelativePath
      self.content = content
      self.wordCount = wordCount
      self.lineCount = lineCount
    }
  }

  private let layout: ShapeTreeDataLayout
  private let log: Logger

  public init(layout: ShapeTreeDataLayout, log: Logger) {
    self.layout = layout
    self.log = log
  }

  /// Lists summaries for every calendar day in `[startDayKey, endDayKey]` (inclusive) that has an on-disk entry.
  public func listSummaries(startDayKey: String, endDayKey: String) throws -> [Summary] {
    guard
      let start = JournalPathCodec.date(fromJournalDayKey: startDayKey),
      let end = JournalPathCodec.date(fromJournalDayKey: endDayKey)
    else {
      throw JournalQueryError.invalidJournalDayKey
    }
    guard start <= end else {
      throw JournalQueryError.invalidRange
    }

    let calendar = JournalPathCodec.utcCalendar
    var out: [Summary] = []
    var cursor = start

    while cursor <= end {
      let dayKey = JournalPathCodec.journalDayKey(for: cursor, calendar: calendar)
      let relativePath = JournalPathCodec.relativeMarkdownPath(for: cursor, calendar: calendar)
      let url = layout.journalRepoRoot.appendingPathComponent(relativePath, isDirectory: false)

      if FileManager.default.fileExists(atPath: url.path),
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

    guard FileManager.default.fileExists(atPath: url.path) else {
      return nil
    }

    let raw = try String(contentsOf: url, encoding: .utf8)
    let counts = Self.wordAndLineCounts(raw)
    return Detail(
      dateKey: dayKey,
      journalRelativePath: relativePath,
      content: raw,
      wordCount: counts.words,
      lineCount: counts.lines)
  }

  private static func wordAndLineCounts(_ content: String) -> (words: Int, lines: Int) {
    let lines = content.components(separatedBy: .newlines)
    let lineCount = lines.count
    let wordCount =
      content
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .count
    return (wordCount, lineCount)
  }
}

public enum JournalQueryError: Error, Sendable, Equatable {
  case invalidJournalDayKey
  case invalidRange
}
