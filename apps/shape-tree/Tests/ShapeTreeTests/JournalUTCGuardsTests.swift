import Foundation
import Logging
import Testing

@testable import ShapeTree

@Suite
struct JournalUTCGuardsTests {

  /// `listSummaries` / `entryDetail` include any yy-MM-dd in range that exists on disk (no server clock filter).
  @Test
  func journalQueryListsDiskFilesForTomorrowKeyWhenPresent() async throws {
    let log = Logger(label: "test.journal-query-inclusive-day-keys")
    let (_, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let query = JournalQueryService(layout: layout, log: log)
    let cal = JournalPathCodec.utcCalendar
    let tomorrow =
      try #require(cal.date(byAdding: .day, value: 1, to: Date()))

    let rel = JournalPathCodec.relativeMarkdownPath(for: tomorrow, calendar: cal)
    let url = layout.journalRepoRoot.appendingPathComponent(rel)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try "bogus".write(to: url, atomically: true, encoding: .utf8)

    let key = JournalPathCodec.journalDayKey(for: tomorrow, calendar: cal)
    let rows = try query.listSummaries(startDayKey: key, endDayKey: key)
    #expect(rows.count == 1)
    #expect(rows[0].dateKey == key)

    let detail = try query.entryDetail(dayKey: key)
    #expect(detail != nil)
    #expect(detail?.content == "bogus")
  }

  /// Filing bucket from `created_at` never advances past wall-clock now when `journal_day` is omitted.
  @Test
  func appendEntryClampsFutureCreatedAtWithoutJournalDay() async throws {
    let log = Logger(label: "test.journal-append-clamp-created-at")
    let (svc, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)

    let path = try await svc.appendEntry(
      subjectIds: ["general"],
      body: "hello",
      createdAt: Date().addingTimeInterval(86400 * 400),
      journalDayKey: nil)

    let expected = JournalPathCodec.relativeMarkdownPath(for: Date())
    #expect(path == expected)
  }

  @Test
  func appendEntryUsesExplicitJournalDayKeyOverCreatedInstant() async throws {
    let log = Logger(label: "test.journal-append-explicit-day")
    let (svc, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)

    let path = try await svc.appendEntry(
      subjectIds: ["general"],
      body: "hello",
      createdAt: Date().addingTimeInterval(86400 * 400),
      journalDayKey: "26-06-15")

    let filingDate =
      try #require(JournalPathCodec.date(fromJournalDayKey: "26-06-15"))
    let expected = JournalPathCodec.relativeMarkdownPath(for: filingDate)
    #expect(path == expected)
  }
}
