import SwiftUI

private enum ComposerPalette {
  static let accentBlue = Color(red: 0, green: 122 / 255, blue: 1)
  static let composerCard = Color(red: 42 / 255, green: 42 / 255, blue: 46 / 255)
  static let editorWell = Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255)
}

private struct JournalContextChipButton: View {
  let label: String
  let isOn: Bool
  let deepChrome: Bool
  let chipFont: Font
  let hp: CGFloat
  let vp: CGFloat
  let action: () -> Void

  private var fill: Color {
    if isOn {
      return ComposerPalette.accentBlue.opacity(deepChrome ? 0.45 : 0.32)
    }
    return deepChrome ? Color.white.opacity(0.09) : Color.secondary.opacity(0.12)
  }

  private var fg: Color {
    if isOn {
      return deepChrome ? Color.white : ComposerPalette.accentBlue
    }
    return deepChrome ? Color.white.opacity(0.88) : Color.primary
  }

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(chipFont)
        .padding(.horizontal, hp)
        .padding(.vertical, vp)
        .background(fill)
        .foregroundStyle(fg)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

/// ShapeTree adaptation of Scribe’s journal composer (chip tray + editor chrome + OpenAPI).
struct ShapeTreeJournalEntryComposer: View {
  @Bindable var viewModel: ShapeTreeViewModel
  var deepChrome: Bool = false
  /// Calendar day bucket for append (`journal_day`); use the sidebar `selectedDate` when inline.
  var journalFilingDate: Date = Date()
  /// When set (typically inline “today” composer), shows Cancel to match Scribe-style chrome.
  var onComposerCancel: (() -> Void)?

  init(
    viewModel: ShapeTreeViewModel,
    deepChrome: Bool = false,
    journalFilingDate: Date = Date(),
    onComposerCancel: (() -> Void)? = nil
  ) {
    self.viewModel = viewModel
    self.deepChrome = deepChrome
    self.journalFilingDate = journalFilingDate
    self.onComposerCancel = onComposerCancel
  }

  @State private var showNewSubjectSheet = false
  @State private var newSubjectDraft = ""

  private var journalSaveSuccessMessage: String? {
    guard let status = viewModel.journalStatus,
      status.localizedCaseInsensitiveContains("saved markdown")
    else { return nil }
    return status
  }

  private var titleForeground: Color {
    deepChrome ? Color.white.opacity(0.94) : Color.primary
  }

  private var secondaryForeground: Color {
    deepChrome ? Color.white.opacity(0.62) : Color.secondary
  }

  var body: some View {
    mainColumn
      .sheet(isPresented: $showNewSubjectSheet, content: newSubjectSheet)
      .alert(
        "Error",
        isPresented: Binding(
          get: { viewModel.journalError != nil },
          set: { if !$0 { viewModel.journalError = nil } }
        )
      ) {
        Button("OK") {
          viewModel.journalError = nil
        }
      } message: {
        Text(viewModel.journalError ?? "")
      }
      .task {
        await viewModel.refreshJournalSubjects()
      }
  }

  @ViewBuilder
  private var mainColumn: some View {
    VStack(spacing: 0) {
      composerToolbar
      composerSuccessBanner
      contextTraySection
      draftEditor
      saveButtonBlock
      composerStatusHint
    }
  }

  @ViewBuilder
  private var composerToolbar: some View {
    HStack(alignment: .center) {
      Text("Add to today")
        #if os(iOS)
          .font(.subheadline.weight(.semibold))
        #else
          .font(.headline)
        #endif
        .foregroundStyle(titleForeground)

      Spacer(minLength: 12)

      Button {
        newSubjectDraft = ""
        viewModel.journalError = nil
        showNewSubjectSheet = true
      } label: {
        Image(systemName: "plus.circle.fill")
          .font(.body.weight(.medium))
          .foregroundStyle(secondaryForeground)
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isJournalWorking)
      .accessibilityLabel("New context")

      Button {
        Task { await viewModel.refreshJournalSubjects() }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.body.weight(.medium))
          .foregroundStyle(secondaryForeground)
      }
      .buttonStyle(.plain)
      .disabled(viewModel.isJournalWorking)
      .accessibilityLabel("Refresh contexts")

      if let onComposerCancel {
        Button("Cancel", action: onComposerCancel)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(ComposerPalette.accentBlue)
          .buttonStyle(.plain)
          .keyboardShortcut(.cancelAction)
      }
    }
    #if os(iOS)
    .padding(.horizontal, 12)
    .padding(.top, 4)
    .padding(.bottom, 6)
    #else
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 6)
    #endif
  }

  @ViewBuilder
  private var composerSuccessBanner: some View {
    if let successMessage = journalSaveSuccessMessage {
      HStack {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
        Text(successMessage)
          .font(.caption)
          .foregroundStyle(secondaryForeground)
        Spacer()
      }
      #if os(iOS)
      .padding(.horizontal, 12)
      #else
      .padding(.horizontal, 16)
      #endif
      .padding(.top, 4)
    }
  }

  @ViewBuilder
  private var contextTraySection: some View {
    VStack(alignment: .leading, spacing: contextSectionSpacing) {
      Text("Context")
        #if os(iOS)
          .font(.caption.weight(.semibold))
        #else
          .font(.subheadline.weight(.semibold))
        #endif
        .foregroundStyle(secondaryForeground)

      contextChipScroll

      if viewModel.journalSubjects.isEmpty {
        Text("No contexts yet. Tap + to add one (or refresh once the server is running).")
          .font(.caption)
          .foregroundStyle(deepChrome ? Color.white.opacity(0.45) : Color.secondary.opacity(0.55))
      }
    }
    .padding(.horizontal, composerHorizontalPadding)
  }

  private var contextChipScroll: some View {
    ZStack(alignment: .trailing) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: contextChipSpacing) {
          ForEach(viewModel.journalSubjects) { subject in
            let isOn = viewModel.journalSelectedSubjectIDs.contains(subject.id)
            JournalContextChipButton(
              label: subject.label,
              isOn: isOn,
              deepChrome: deepChrome,
              chipFont: contextChipFont,
              hp: contextChipHPadding,
              vp: contextChipVPadding
            ) {
              viewModel.toggleJournalSubjectSelection(subject.id)
            }
          }
        }
        .padding(.vertical, 1)
        .padding(.trailing, 28)
      }

      contextSubjectsTrailingFade

      Image(systemName: "chevron.compact.right")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(deepChrome ? Color.white.opacity(0.22) : Color.secondary.opacity(0.55))
        .accessibilityHidden(true)
        .padding(.trailing, 6)
        .allowsHitTesting(false)
    }
    .padding(contextTrayPadding)
    .background(
      RoundedRectangle(cornerRadius: contextTrayCornerRadius, style: .continuous)
        .fill(deepChrome ? Color.black.opacity(0.28) : Color.secondary.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: contextTrayCornerRadius, style: .continuous)
        .stroke(
          deepChrome ? Color.white.opacity(0.08) : Color.secondary.opacity(0.22),
          lineWidth: 1)
    )
  }

  private var draftEditor: some View {
    TextEditor(text: $viewModel.journalDraft)
      #if os(macOS)
      .font(.system(size: 18))
      #else
      .font(.body)
      .fontDesign(.monospaced)
      #endif
      .foregroundStyle(deepChrome ? Color.white.opacity(0.92) : Color.primary)
      .scrollContentBackground(.hidden)
      .padding(textEditorInnerPadding)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(deepChrome ? ComposerPalette.editorWell : Color.accentColor.opacity(0.06))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(
            deepChrome ? Color.white.opacity(0.07) : Color.accentColor.opacity(0.12),
            lineWidth: 1)
      )
      .padding(.horizontal, composerHorizontalPadding)
      .padding(.top, textEditorOuterTopPadding)
      .padding(.bottom, textEditorOuterBottomPadding)
      .frame(minHeight: textEditorMinHeight)
  }

  private var saveButtonBlock: some View {
    Button(action: saveEntry) {
      Text(viewModel.isJournalWorking ? "Saving…" : "Save Entry")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(saveDisabled ? Color.gray.opacity(0.45) : ComposerPalette.accentBlue)
        )
    }
    .buttonStyle(.plain)
    .disabled(saveDisabled)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, composerHorizontalPadding)
    .padding(.bottom, saveRowBottomPadding)
  }

  @ViewBuilder
  private var composerStatusHint: some View {
    if let hint = viewModel.journalStatus, journalSaveSuccessMessage == nil {
      Text(hint)
        .font(.footnote)
        .foregroundStyle(secondaryForeground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, composerHorizontalPadding)
        .padding(.bottom, 8)
    }
  }

  @ViewBuilder
  private func newSubjectSheet() -> some View {
    NavigationStack {
      Form {
        TextField("Subject label", text: $newSubjectDraft)
          #if os(iOS)
          .textInputAutocapitalization(.words)
          #endif
      }
      .navigationTitle("New subject")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            showNewSubjectSheet = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            let raw = newSubjectDraft
            Task {
              let ok = await viewModel.appendJournalSubjectAndRefresh(raw)
              if ok {
                newSubjectDraft = ""
                showNewSubjectSheet = false
              }
            }
          }
          .disabled(newSubjectDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 340, minHeight: 200)
    #endif
  }

  private var saveDisabled: Bool {
    viewModel.journalDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || viewModel.journalSelectedSubjectIDs.isEmpty
      || viewModel.isJournalWorking
  }

  private func saveEntry() {
    Task {
      await viewModel.appendJournalEntryUsingServer(filingDate: journalFilingDate)
    }
  }

  private var contextSectionSpacing: CGFloat {
    #if os(iOS)
    4
    #else
    6
    #endif
  }

  private var contextChipSpacing: CGFloat {
    #if os(iOS)
    6
    #else
    8
    #endif
  }

  private var contextChipFont: Font {
    #if os(iOS)
    .caption
    #else
    .subheadline
    #endif
  }

  private var contextChipHPadding: CGFloat {
    #if os(iOS)
    8
    #else
    12
    #endif
  }

  private var contextChipVPadding: CGFloat {
    #if os(iOS)
    4
    #else
    6
    #endif
  }

  private var contextTrayPadding: CGFloat {
    #if os(iOS)
    6
    #else
    8
    #endif
  }

  private var contextTrayCornerRadius: CGFloat {
    #if os(iOS)
    8
    #else
    10
    #endif
  }

  private var composerHorizontalPadding: CGFloat {
    #if os(iOS)
    12
    #else
    16
    #endif
  }

  private var textEditorInnerPadding: CGFloat {
    #if os(iOS)
    4
    #else
    6
    #endif
  }

  private var textEditorOuterTopPadding: CGFloat {
    #if os(iOS)
    4
    #else
    8
    #endif
  }

  private var textEditorOuterBottomPadding: CGFloat {
    #if os(iOS)
    6
    #else
    8
    #endif
  }

  private var textEditorMinHeight: CGFloat {
    #if os(iOS)
    120
    #else
    220
    #endif
  }

  private var saveRowBottomPadding: CGFloat {
    #if os(iOS)
    4
    #else
    8
    #endif
  }

  private var contextSubjectsTrailingFade: some View {
    LinearGradient(
      colors: [
        Color.clear,
        (deepChrome ? Color.black.opacity(0.5) : Color.secondary.opacity(0.14)),
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
    .frame(width: 36)
    .allowsHitTesting(false)
  }
}

private struct ShapeTreeJournalInlineComposerChromeModifier: ViewModifier {
  let deepChrome: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if deepChrome {
      deepChromeChrome(content)
    } else {
      lightChrome(content)
    }
  }

  @ViewBuilder
  private func deepChromeChrome(_ content: Content) -> some View {
    #if os(iOS)
      content
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(ComposerPalette.composerCard)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 28, y: 14)
    #else
      content
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(ComposerPalette.composerCard)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 28, y: 14)
    #endif
  }

  @ViewBuilder
  private func lightChrome(_ content: Content) -> some View {
    #if os(iOS)
      content
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    #else
      content
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        )
    #endif
  }
}

extension View {
  /// Raised card chrome for inline “today” composer (Scribe-style in dark journal).
  func shapeTreeJournalInlineComposerChrome(deepChrome: Bool = false) -> some View {
    modifier(ShapeTreeJournalInlineComposerChromeModifier(deepChrome: deepChrome))
  }
}
