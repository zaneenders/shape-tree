import SwiftUI

/// ShapeTree adaptation of Scribe’s ``JournalEntryComposer`` chip tray + editor chrome (OpenAPI / journal subjects).
struct ShapeTreeJournalEntryComposer: View {
  @Bindable var viewModel: ShapeTreeViewModel

  private var journalSaveSuccessMessage: String? {
    guard let status = viewModel.journalStatus,
      status.localizedCaseInsensitiveContains("saved markdown")
    else { return nil }
    return status
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center) {
        Text("Add to today")
          #if os(iOS)
            .font(.subheadline.weight(.semibold))
          #else
            .font(.headline)
          #endif
        Spacer()
        Button {
          Task { await viewModel.refreshJournalSubjects() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isJournalWorking)
        .accessibilityLabel("Refresh subjects")
      }
      #if os(iOS)
      .padding(.horizontal, 12)
      .padding(.top, 4)
      .padding(.bottom, 0)
      #else
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 2)
      #endif

      if let successMessage = journalSaveSuccessMessage {
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text(successMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
        }
        #if os(iOS)
        .padding(.horizontal, 12)
        #else
        .padding(.horizontal, 16)
        #endif
        .padding(.top, 4)
      }

      VStack(alignment: .leading, spacing: contextSectionSpacing) {
        Text("Subjects")
          #if os(iOS)
            .font(.caption.weight(.semibold))
          #else
            .font(.subheadline)
          #endif
          .foregroundStyle(.secondary)

        ZStack(alignment: .trailing) {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: contextChipSpacing) {
              ForEach(viewModel.journalSubjects) { subject in
                let isOn = viewModel.journalSelectedSubjectIDs.contains(subject.id)
                Button {
                  viewModel.toggleJournalSubjectSelection(subject.id)
                } label: {
                  Text(subject.label)
                    .font(contextChipFont)
                    .padding(.horizontal, contextChipHPadding)
                    .padding(.vertical, contextChipVPadding)
                    .background(isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
                    .foregroundStyle(isOn ? Color.accentColor : Color.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.vertical, 1)
            .padding(.trailing, 28)
          }

          contextSubjectsTrailingFade

          Image(systemName: "chevron.compact.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
            .padding(.trailing, 6)
            .allowsHitTesting(false)
        }
        .padding(contextTrayPadding)
        .background(
          RoundedRectangle(cornerRadius: contextTrayCornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
          RoundedRectangle(cornerRadius: contextTrayCornerRadius, style: .continuous)
            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        )

        if viewModel.journalSubjects.isEmpty {
          Text("No subjects yet. Tap refresh above after the server is running.")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
      }
      .padding(.horizontal, composerHorizontalPadding)

      TextEditor(text: $viewModel.journalDraft)
        #if os(macOS)
        .font(.system(size: 18))
        #else
        .font(.body)
        .fontDesign(.monospaced)
        #endif
        .scrollContentBackground(.hidden)
        .padding(textEditorInnerPadding)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(6)
        .padding(.horizontal, composerHorizontalPadding)
        .padding(.top, textEditorOuterTopPadding)
        .padding(.bottom, textEditorOuterBottomPadding)
        .frame(minHeight: textEditorMinHeight)

      Group {
        #if os(iOS)
        Button(action: saveEntry) {
          Text(viewModel.isJournalWorking ? "Saving…" : "Save")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(saveDisabled)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, composerHorizontalPadding)
        #else
        HStack {
          Spacer()
          Button(action: saveEntry) {
            Text(viewModel.isJournalWorking ? "Saving…" : "Save entry")
              .padding(.horizontal, 20)
              .padding(.vertical, 10)
          }
          .buttonStyle(.borderedProminent)
          .disabled(saveDisabled)
          Spacer()
        }
        #endif
      }
      .padding(.bottom, saveRowBottomPadding)

      if let hint = viewModel.journalStatus, journalSaveSuccessMessage == nil {
        Text(hint)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, composerHorizontalPadding)
          .padding(.bottom, 8)
      }
    }
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
    #if os(macOS)
    .frame(minWidth: 520)
    #endif
    .task {
      await viewModel.refreshJournalSubjects()
    }
  }

  private var saveDisabled: Bool {
    viewModel.journalDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || viewModel.journalSelectedSubjectIDs.isEmpty
      || viewModel.isJournalWorking
  }

  private func saveEntry() {
    Task {
      await viewModel.appendJournalEntryUsingServer()
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
        Color.secondary.opacity(0.14),
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
    .frame(width: 36)
    .allowsHitTesting(false)
  }
}

extension View {
  /// Card chrome matching Scribe’s inline journal composer.
  @ViewBuilder
  func shapeTreeJournalInlineComposerChrome() -> some View {
    #if os(iOS)
    self
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
    self
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
