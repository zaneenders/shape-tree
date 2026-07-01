import Foundation
import Markdown

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
  public static func split(_ source: String) -> (frontMatter: FrontMatter, body: String) {
    let sourceWithoutBOM = source.hasPrefix("\u{FEFF}") ? String(source.dropFirst()) : source
    var parser = FrontMatterDocumentParser()
    parser.parse(Document(parsing: sourceWithoutBOM))
    return parser.finish(source: sourceWithoutBOM)
  }
}

private struct FrontMatterDocumentParser {
  var frontMatter = FrontMatter()
  var bodyBlocks: [BlockMarkup] = []

  private enum Phase {
    case start
    case meta
    case body
  }

  private var phase: Phase = .start
  private var sawOpeningBreak = false
  private var expectingTagsList = false

  mutating func parse(_ document: Document) {
    for child in document.children {
      switch phase {
      case .start:
        if child is ThematicBreak {
          sawOpeningBreak = true
          phase = .meta
        } else {
          phase = .body
          appendBodyBlock(child)
        }
      case .meta:
        if child is ThematicBreak {
          phase = .body
          expectingTagsList = false
        } else if let heading = child as? Heading {
          parseMetadataLine(heading.plainText)
          phase = .body
          expectingTagsList = false
        } else if expectingTagsList, let list = child as? UnorderedList {
          parseTagsList(list)
          expectingTagsList = false
        } else if let paragraph = child as? Paragraph {
          parseMetadataParagraph(paragraph)
        }
      case .body:
        appendBodyBlock(child)
      }
    }
  }

  func finish(source: String) -> (FrontMatter, String) {
    if !sawOpeningBreak || phase == .meta {
      return (FrontMatter(), source)
    }
    let body =
      bodyBlocks.isEmpty
      ? ""
      : Document(bodyBlocks).format().trimmingCharacters(in: .newlines)
    return (frontMatter, body)
  }

  private mutating func appendBodyBlock(_ markup: any Markup) {
    if let block = markup as? BlockMarkup {
      bodyBlocks.append(block)
    }
  }

  private mutating func parseMetadataParagraph(_ paragraph: Paragraph) {
    for line in metadataLines(in: paragraph) {
      parseMetadataLine(line)
    }
  }

  private func metadataLines(in paragraph: Paragraph) -> [String] {
    var lines: [String] = []
    var current = ""

    for child in paragraph.inlineChildren {
      if child is SoftBreak || child is LineBreak {
        lines.append(current)
        current = ""
      } else if let text = child as? Text {
        current += text.string
      }
    }

    if !current.isEmpty {
      lines.append(current)
    }
    return lines
  }

  private mutating func parseMetadataLine(_ line: String) {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      expectingTagsList = false
      return
    }

    guard let separator = trimmed.firstIndex(of: ":") else {
      expectingTagsList = false
      return
    }

    let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
    let value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)

    switch key {
    case "title":
      expectingTagsList = false
      frontMatter.title = stripQuotes(value)
    case "date":
      expectingTagsList = false
      frontMatter.date = parseDate(stripQuotes(value))
    case "excerpt":
      expectingTagsList = false
      frontMatter.excerpt = stripQuotes(value)
    case "tags":
      if value.isEmpty {
        expectingTagsList = true
        frontMatter.tags = []
      } else {
        expectingTagsList = false
        frontMatter.tags =
          value
          .split(separator: ",")
          .map { stripQuotes(String($0).trimmingCharacters(in: .whitespaces)) }
          .filter { !$0.isEmpty }
      }
    default:
      expectingTagsList = false
    }
  }

  private mutating func parseTagsList(_ list: UnorderedList) {
    for child in list.children {
      guard let item = child as? ListItem else { continue }
      for itemChild in item.children {
        guard let paragraph = itemChild as? Paragraph else { continue }
        for line in metadataLines(in: paragraph) {
          let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
          if trimmed.isEmpty { continue }

          if isMetadataLine(trimmed) {
            parseMetadataLine(trimmed)
            continue
          }

          let value =
            trimmed.hasPrefix("- ")
            ? String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            : trimmed
          if !value.isEmpty {
            frontMatter.tags.append(stripQuotes(value))
          }
        }
      }
    }
  }

  private func isMetadataLine(_ line: String) -> Bool {
    guard let separator = line.firstIndex(of: ":") else { return false }
    let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
    switch key {
    case "title", "date", "tags", "excerpt":
      return true
    default:
      return false
    }
  }

  private func stripQuotes(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
      return String(value.dropFirst().dropLast())
    }
    return value
  }

  private func parseDate(_ value: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withFullDate]
    if let date = iso.date(from: value) {
      return date
    }
    if let date = DateFormatting.date(fromShortFormat: value) {
      return date
    }
    return DateFormatting.date(fromFilename: value)
  }
}
