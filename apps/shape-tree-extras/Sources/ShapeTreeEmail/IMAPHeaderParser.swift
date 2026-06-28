import Foundation
import RegexBuilder

package enum IMAPHeaderParser {
  private static var headerField: Regex<(Substring, Substring, Substring)> {
    Regex {
      Capture {
        OneOrMore(.word)
      }
      ":"
      Optionally {
        OneOrMore(.whitespace)
      }
      Capture {
        OneOrMore(.any)
      }
    }
  }

  package static func parseHeaders(_ text: String) -> [String: String] {
    var headers: [String: String] = [:]
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    for line in normalized.split(separator: "\n", omittingEmptySubsequences: true) {
      guard let match = line.firstMatch(of: headerField) else { continue }
      let name = String(match.output.1).trimmingCharacters(in: .whitespaces).lowercased()
      let value = String(match.output.2).trimmingCharacters(in: .whitespaces)
      if !name.isEmpty {
        headers[name] = value
      }
    }
    return headers
  }
}
