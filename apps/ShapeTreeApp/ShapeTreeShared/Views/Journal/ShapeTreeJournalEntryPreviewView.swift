import ShapeTreeClient
import SwiftUI

/// Read-only preview of a single day's entry. Renders one of: loading spinner, error, sectioned
/// Markdown body, or an empty-state with a "Write today's entry" call-to-action.
struct ShapeTreeJournalEntryPreviewView: View {
  let journalModel: ShapeTreeViewModel
  let date: Date
  let entryRefreshToken: UUID
  let deepChrome: Bool
  let onWriteToday: () -> Void

  @State private var isLoading = false
  @State private var detail: Components.Schemas.JournalEntryDetailResponse?
  @State private var loadError: String?

  private var entryLoadTaskId: String {
    "\(ShapeTreeJournalLocalFormatting.dayKey(for: date))-\(entryRefreshToken.uuidString)"
  }

  private var previewSectionFont: Font {
    #if os(macOS)
    .system(size: 17)
    #elseif os(iOS)
    .body
    #else
    .body
    #endif
  }

  private var entryPreviewEmptyMinHeight: CGFloat {
    #if os(iOS)
    120
    #else
    200
    #endif
  }

  var body: some View {
    Group {
      if isLoading {
        loadingBlock
      } else if let loadError {
        errorBlock(error: loadError)
      } else if let detail {
        entryDetailBlock(detail: detail)
      } else {
        emptyBlock
      }
    }
    .task(id: entryLoadTaskId) {
      await load()
    }
  }

  private var loadingBlock: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Loading entry...")
        .font(.caption)
        .foregroundStyle(deepChrome ? Color.white.opacity(0.5) : Color.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
  }

  private func errorBlock(error: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text(error)
        .font(.caption)
        .multilineTextAlignment(.center)
        .foregroundStyle(deepChrome ? Color.white.opacity(0.55) : Color.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
  }

  private func entryDetailBlock(detail: Components.Schemas.JournalEntryDetailResponse) -> some View {
    let wordText = detail.word_count == 1 ? "word" : "words"
    let lineText = detail.line_count == 1 ? "line" : "lines"

    return VStack(alignment: .leading, spacing: 16) {
      Text("\(detail.word_count) \(wordText) — \(detail.line_count) \(lineText)")
        #if os(iOS)
      .font(.caption)
        #else
      .font(.subheadline)
        #endif
        .foregroundStyle(deepChrome ? Color.white.opacity(0.45) : Color.secondary)

      JournalEntrySectionedBody(
        sections: JournalEntrySectioning.sections(from: detail.content),
        textFont: previewSectionFont,
        lineSpacing: 5,
        sectionSeparator: .scribeSpacing
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      .tint(ShapeTreeJournalPalette.accentBlue)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var emptyBlock: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text")
        #if os(iOS)
      .font(.title2)
        #else
      .font(.largeTitle)
        #endif
        .foregroundStyle(deepChrome ? Color.white.opacity(0.38) : Color.secondary)
      Text("No entry for this date")
        .font(.subheadline)
        .foregroundStyle(deepChrome ? Color.white.opacity(0.5) : Color.secondary)

      if ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(date) {
        Button("Write today's entry") {
          onWriteToday()
        }
        .buttonStyle(.borderedProminent)
        .tint(ShapeTreeJournalPalette.accentBlue)
        .controlSize(.small)
      }
    }
    .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
  }

  private func load() async {
    isLoading = true
    loadError = nil
    detail = nil
    defer { isLoading = false }

    let key = ShapeTreeJournalLocalFormatting.dayKey(for: date)

    guard !journalModel.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      loadError = "Enter a ShapeTree server URL in Chat first."
      return
    }

    do {
      detail = try await journalModel.fetchJournalEntryDetailIfPresent(dayKey: key)
    } catch {
      loadError = error.localizedDescription
    }
  }
}
