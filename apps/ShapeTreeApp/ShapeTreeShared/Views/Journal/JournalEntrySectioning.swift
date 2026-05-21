import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum JournalEntrySectioning {

  private static func strippingLegacyHeadingTimestamps(_ raw: String) -> String {
    guard
      let regex = try? NSRegularExpression(
        pattern: #"(?m)^(#[^\n]+\n)\n*(\d{4}-\d{2}-\d{2}T[^\n]+)\n+"#,
        options: []
      )
    else { return raw }
    let range = NSRange(raw.startIndex..., in: raw)
    return regex.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: "$1\n")
  }

  static func sections(from raw: String) -> [String] {
    let unified = strippingLegacyHeadingTimestamps(raw.replacingOccurrences(of: "\r\n", with: "\n"))
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
        .foregroundStyle(Color.secondary.opacity(0.45))
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
  var sectionSeparator: SectionSeparator = .iconRule

  enum SectionSeparator {
    case iconRule
    case scribeSpacing
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
        if index > 0 {
          switch sectionSeparator {
          case .iconRule:
            JournalEntrySectionDivider()
              .padding(.vertical, 10)
          case .scribeSpacing:
            Color.clear
              .frame(height: 20)
          }
        }
        sectionBody(section)
      }
    }
  }

  @ViewBuilder
  private func sectionBody(_ section: String) -> some View {
    let attributed = styledJournalMarkdown(section)
    #if os(iOS)
    JournalSelectableSectionText(attributedText: attributed, lineSpacing: lineSpacing)
      .frame(maxWidth: .infinity, alignment: .leading)
    #else
    // A single `.font` on `Text(AttributedString)` collapses all typography to one run —
    // headings never look like headings. Per-range fonts from presentation intents fix this.
    Text(attributed)
      .lineSpacing(lineSpacing)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    #endif
  }

  private func styledJournalMarkdown(_ raw: String) -> AttributedString {
    var opts = AttributedString.MarkdownParsingOptions()
    opts.interpretedSyntax = .full
    opts.failurePolicy = .returnPartiallyParsedIfPossible
    var output = (try? AttributedString(markdown: raw, options: opts)) ?? AttributedString(raw)
    // `AttributedString(markdown:)` encodes block structure only in `PresentationIntent`, not as
    // newline characters—so `# General` + `ok` becomes adjacent runs spelling `Generalok` and SwiftUI
    // draws them on one line. Restore spacing whenever the presentation-intent “container” changes.
    output = Self.reinsertMarkdownBlockNewlines(output)

    let presentation = AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self
    // Reverse so attribute mutations remain stable over ranges.
    for (intent, range) in output.runs[presentation].reversed() {
      guard let intent else {
        Self.applyBodyFont(to: &output, range: range, textFont: textFont)
        continue
      }
      var resolved = textFont
      var headerLevel: Int?
      for component in intent.components {
        if case .header(let level) = component.kind {
          resolved = Self.headerFont(for: level)
          headerLevel = level
          break
        }
      }
      output[range].swiftUI.font = resolved
      #if canImport(UIKit)
      output[range].uiKit.font =
        headerLevel.map(Self.uiFont(forHeaderLevel:))
        ?? Self.uiFont(for: textFont)
      #endif
    }

    return output
  }

  private static func applyBodyFont(
    to output: inout AttributedString,
    range: Range<AttributedString.Index>,
    textFont: Font
  ) {
    output[range].swiftUI.font = textFont
    #if canImport(UIKit)
    output[range].uiKit.font = uiFont(for: textFont)
    #endif
  }

  /// Inserts paragraph breaks between Markdown block runs. Required because Foundation’s Markdown
  /// → `AttributedString` conversion does not insert `\n` between headers/paragraphs/list items—the
  /// character view can literally read `Generalok` while the runs still carry distinct intents.
  private static func reinsertMarkdownBlockNewlines(_ source: AttributedString) -> AttributedString {
    var out = AttributedString()
    var isFirst = true
    var previousIntent: PresentationIntent?
    for run in source.runs {
      if !isFirst, previousIntent != run.presentationIntent {
        out.append(AttributedString("\n\n"))
      }
      out.append(source[run.range])
      previousIntent = run.presentationIntent
      isFirst = false
    }
    return out
  }

  private static func headerFont(for level: Int) -> Font {
    switch level {
    case 1:
      return .title2.weight(.bold)
    case 2:
      return .title3.weight(.semibold)
    case 3:
      return .headline.weight(.semibold)
    default:
      return .headline.weight(.semibold)
    }
  }

  #if canImport(UIKit)
  private static func uiFont(for textFont: Font) -> UIFont {
    _ = textFont
    return UIFont.preferredFont(forTextStyle: .body)
  }

  private static func uiFont(forHeaderLevel level: Int) -> UIFont {
    switch level {
    case 1:
      return UIFont.preferredFont(forTextStyle: .title2).withWeight(.bold)
    case 2:
      return UIFont.preferredFont(forTextStyle: .title3).withWeight(.semibold)
    case 3:
      return UIFont.preferredFont(forTextStyle: .headline).withWeight(.semibold)
    default:
      return UIFont.preferredFont(forTextStyle: .headline).withWeight(.semibold)
    }
  }
  #endif
}

#if os(iOS)
private struct JournalSelectableSectionText: UIViewRepresentable {
  let attributedText: AttributedString
  let lineSpacing: CGFloat

  func makeUIView(context: Context) -> JournalSizingTextView {
    let textView = JournalSizingTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = false
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.dataDetectorTypes = []
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    textView.setContentHuggingPriority(.required, for: .vertical)
    return textView
  }

  func updateUIView(_ textView: JournalSizingTextView, context: Context) {
    textView.attributedText = nsAttributedText
  }

  private var nsAttributedText: NSAttributedString {
    let bridged = NSAttributedString(attributedText)
    let mutable = NSMutableAttributedString(attributedString: bridged)
    let fullRange = NSRange(location: 0, length: mutable.length)
    guard fullRange.length > 0 else { return mutable }

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = lineSpacing
    mutable.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: fullRange)

    mutable.enumerateAttribute(NSAttributedString.Key.foregroundColor, in: fullRange) { value, range, _ in
      guard value == nil else { return }
      mutable.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.label, range: range)
    }

    return mutable
  }
}

private final class JournalSizingTextView: UITextView {
  override var intrinsicContentSize: CGSize {
    let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
    let measured = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: UIView.noIntrinsicMetric, height: measured.height)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    invalidateIntrinsicContentSize()
  }
}

extension UIFont {
  fileprivate func withWeight(_ weight: UIFont.Weight) -> UIFont {
    let descriptor = fontDescriptor.addingAttributes([
      .traits: [UIFontDescriptor.TraitKey.weight: weight]
    ])
    return UIFont(descriptor: descriptor, size: pointSize)
  }
}
#endif
