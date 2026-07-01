import Foundation

public enum DateFormatting {
  public static func displayString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  public static func isoString(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.string(from: date)
  }

  public static func date(fromFilename string: String) -> Date? {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: string)
  }

  public static func date(fromShortFormat string: String) -> Date? {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yy-MM-dd"
    return formatter.date(from: string)
  }
}
