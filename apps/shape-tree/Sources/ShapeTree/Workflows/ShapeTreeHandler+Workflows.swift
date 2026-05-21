import Foundation
import ShapeTreeClient

extension ShapeTreeHandler {

  // MARK: POST /workflows/daily-summary

  func runDailySummary(
    _ input: Operations.runDailySummary.Input
  ) async throws -> Operations.runDailySummary.Output {
    guard let service = dailySummaryService else {
      return .internalServerError(
        .init(body: .json(Self.errorBody("Daily summary service not configured."))))
    }
    let dayKey = input.query.day ?? JournalPathCodec.journalDayKey(for: Date())
    guard JournalPathCodec.date(fromJournalDayKey: dayKey) != nil else {
      return .badRequest(.init(body: .json(Self.errorBody("day must be formatted yy-MM-dd."))))
    }
    do {
      let output = try await service.summarizeDay(dayKey: dayKey)
      return .ok(
        .init(body: .json(.init(day: output.dayKey, summary: output.summary, entry_count: output.entryCount))))
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(event: "summary.failed", error, public: "Failed to generate daily summary."))))
    }
  }

  // MARK: GET /workflows/daily-summary/{day}

  func getDailySummary(
    _ input: Operations.getDailySummary.Input
  ) async throws -> Operations.getDailySummary.Output {
    guard let service = dailySummaryService else {
      return .notFound(.init(body: .json(Self.errorBody("Daily summary service not configured."))))
    }
    let dayKey = input.path.day
    guard JournalPathCodec.date(fromJournalDayKey: dayKey) != nil else {
      return .badRequest(.init(body: .json(Self.errorBody("day must be formatted yy-MM-dd."))))
    }
    let summaryURL = service.summariesDirectory.appendingPathComponent("\(dayKey).md", isDirectory: false)
    guard FileManager.default.fileExists(atPath: summaryURL.path),
      let content = try? String(contentsOf: summaryURL, encoding: .utf8)
    else {
      return .notFound(.init(body: .json(Self.errorBody("No summary for \(dayKey)."))))
    }
    return .ok(
      .init(body: .json(.init(day: dayKey, summary: content, entry_count: 0))))
  }
}
