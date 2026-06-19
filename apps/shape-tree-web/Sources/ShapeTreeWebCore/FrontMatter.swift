import Foundation

public struct FrontMatter: Sendable, Equatable {
  public var title: String?
  public var date: Date?
  public var tags: [String]
  public var excerpt: String?

  public init(
    title: String? = nil,
    date: Date? = nil,
    tags: [String] = [],
    excerpt: String? = nil
  ) {
    self.title = title
    self.date = date
    self.tags = tags
    self.excerpt = excerpt
  }
}

public enum FrontMatterParser: Sendable {
  /// Splits Jekyll-style `---` front matter from the Markdown body.
  public static func split(_ source: String) -> (frontMatter: FrontMatter, body: String) {
    let normalized = source.hasPrefix("\u{FEFF}") ? String(source.dropFirst()) : source
    guard normalized.hasPrefix("---") else {
      return (FrontMatter(), normalized)
    }

    let afterOpening = normalized.dropFirst(3)
    guard let closingRange = afterOpening.range(of: "\n---", options: [], locale: nil) else {
      return (FrontMatter(), normalized)
    }

    let yaml = String(afterOpening[..<closingRange.lowerBound]).trimmingCharacters(in: .newlines)
    let bodyStart = closingRange.upperBound
    let body =
      bodyStart < afterOpening.endIndex
      ? String(afterOpening[bodyStart...]).trimmingCharacters(in: .newlines)
      : ""

    return (parseYAML(yaml), body)
  }

  private static func parseYAML(_ yaml: String) -> FrontMatter {
    var frontMatter = FrontMatter()
    var currentListKey: String?

    for rawLine in yaml.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = String(rawLine)
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.isEmpty {
        currentListKey = nil
        continue
      }

      if trimmed.hasPrefix("- "), let key = currentListKey, key == "tags" {
        let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        if !value.isEmpty {
          frontMatter.tags.append(stripQuotes(value))
        }
        continue
      }

      currentListKey = nil
      guard let separator = trimmed.firstIndex(of: ":") else { continue }

      let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
      let value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)

      switch key {
      case "title":
        frontMatter.title = stripQuotes(value)
      case "date":
        frontMatter.date = parseDate(stripQuotes(value))
      case "excerpt":
        frontMatter.excerpt = stripQuotes(value)
      case "tags":
        if value.isEmpty {
          currentListKey = "tags"
          frontMatter.tags = []
        } else {
          frontMatter.tags =
            value
            .split(separator: ",")
            .map { stripQuotes(String($0).trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
        }
      default:
        break
      }
    }

    return frontMatter
  }

  private static func stripQuotes(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
      return String(value.dropFirst().dropLast())
    }
    return value
  }

  private static func parseDate(_ value: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withFullDate]
    if let date = iso.date(from: value) {
      return date
    }

    let civil = DateFormatter()
    civil.calendar = Calendar(identifier: .gregorian)
    civil.locale = Locale(identifier: "en_US_POSIX")
    civil.timeZone = TimeZone(secondsFromGMT: 0)
    civil.dateFormat = "yyyy-MM-dd"
    return civil.date(from: value)
  }
}
