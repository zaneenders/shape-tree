import Foundation

enum SMTPMessageEncoding {
  static func sanitizeHeaderValue(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\r", with: "")
      .replacingOccurrences(of: "\n", with: "")
  }

  static func dotStuffedBody(_ body: String) -> String {
    let normalized =
      body
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    var lines: [String] = []
    var current = ""
    for character in normalized {
      if character == "\n" {
        lines.append(current)
        current = ""
      } else {
        current.append(character)
      }
    }
    lines.append(current)

    return lines.map { line in
      line.hasPrefix(".") ? "." + line : line
    }.joined(separator: "\r\n")
  }

  static func rfc5322DateString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return formatter.string(from: date)
  }
}
