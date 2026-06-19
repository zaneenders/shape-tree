import Foundation

/// Day-key + repo-relative path codec for journal Markdown. Shared between server and apps so
/// the on-disk layout (`yy/MM/yy-MM-dd.md`) and the request-payload key (`yy-MM-dd`) cannot drift.
public enum JournalPathCodec: Sendable {

  public static var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  /// Scribe layout: `yy/MM/yy-MM-dd.md` under the journal git root.
  public static func relativeMarkdownPath(for date: Date, calendar: Calendar = utcCalendar) -> String {
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    let yy = year % 100
    return String(format: "%02d/%02d/%02d-%02d-%02d.md", yy, month, yy, month, day)
  }

  /// Two-digit journal day key `yy-MM-dd` (Gregorian civil date components from the given calendar).
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
