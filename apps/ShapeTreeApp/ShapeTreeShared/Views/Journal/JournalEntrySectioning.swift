import SwiftUI

enum JournalEntrySectioning {
  /// Splits raw journal markdown on lines that are thematic breaks (three or more `-` after trimming whitespace).
  ///
  /// **Note:** A line of only dashes inside entry *body* becomes a visible section boundary (unlike the older reader that stripped `-----`). Prefer prose or headings if you need a horizontal rule without splitting.
  static func sections(from raw: String) -> [String] {
    let unified = raw.replacingOccurrences(of: "\r\n", with: "\n")
    var result: [String] = []
    var currentLines: [String] = []

    func flush() {
      let piece = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      if !piece.isEmpty { result.append(piece) }
      currentLines.removeAll(keepingCapacity: true)
    }

    let lines = unified.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.allSatisfy({ $0 == "-" }) && trimmed.count >= 3 {
        flush()
      } else {
        currentLines.append(line)
      }
    }
    flush()

    if result.isEmpty {
      let trimmed = unified.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? [] : [trimmed]
    }
    return result
  }
}

struct JournalEntrySectionDivider: View {
  var body: some View {
    HStack(spacing: 10) {
      Rectangle()
        .fill(Color.secondary.opacity(0.22))
        .frame(height: 1)
      Image(systemName: "rectangle.split.1x2")
        .font(.caption2.weight(.medium))
        .foregroundStyle(.tertiary)
        .accessibilityLabel("Section break")
      Rectangle()
        .fill(Color.secondary.opacity(0.22))
        .frame(height: 1)
    }
  }
}

struct JournalEntrySectionedBody: View {
  let sections: [String]
  var textFont: Font
  var lineSpacing: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
        if index > 0 {
          JournalEntrySectionDivider()
            .padding(.vertical, 10)
        }
        Text(section)
          .font(textFont)
          .lineSpacing(lineSpacing)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
    }
  }
}
