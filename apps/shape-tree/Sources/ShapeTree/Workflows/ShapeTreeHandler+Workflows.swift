import Foundation
import ShapeTreeClient

extension ShapeTreeHandler {

  // MARK: GET /summaries/{day}

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
