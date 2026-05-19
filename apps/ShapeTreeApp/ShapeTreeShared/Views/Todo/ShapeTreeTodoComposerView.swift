import SwiftUI

struct ShapeTreeTodoComposerView: View {
  @Binding var text: String
  let attachmentHint: String?
  let isFieldDisabled: Bool
  let isSendDisabled: Bool
  let onSend: () async -> Void
  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 10) {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(
            isFieldDisabled
              ? Color.secondary.opacity(0.4)
              : ShapeTreeTodoPalette.accentBlue.opacity(isFocused ? 1 : 0.85)
          )

        TextField("Add a todo…", text: $text)
          .textFieldStyle(.plain)
          .font(.body)
          .focused($isFocused)
          .disabled(isFieldDisabled)
          .onSubmit { sendIfValid() }

        Button(action: sendIfValid) {
          Image(systemName: "arrow.up.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .foregroundStyle(
              cannotSend
                ? Color.secondary.opacity(0.35)
                : ShapeTreeTodoPalette.accentBlue
            )
        }
        .buttonStyle(.plain)
        .disabled(cannotSend)
        .keyboardShortcut(.return, modifiers: [.command])
        .accessibilityLabel("Add todo")
        #if os(macOS)
        .help("Add todo (⌘↩)")
        #endif
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(composerFieldFill)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(composerStroke, lineWidth: isFocused ? 1.5 : 1)
      }
      #if os(macOS)
      .shadow(
        color: isFocused ? ShapeTreeTodoPalette.accentBlue.opacity(0.2) : .clear,
        radius: isFocused ? 8 : 0,
        y: 2
      )
      #endif

      if let attachmentHint, isFocused || !text.isEmpty {
        Text(attachmentHint)
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .padding(.leading, 4)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(composerBarBackground)
  }

  private var cannotSend: Bool {
    isSendDisabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var composerFieldFill: some ShapeStyle {
    LinearGradient(
      colors: [
        ShapeTreeTodoPalette.accentBlue.opacity(isFocused ? 0.2 : 0.14),
        ShapeTreeTodoPalette.accentBlue.opacity(isFocused ? 0.1 : 0.06),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var composerStroke: Color {
    if isFocused {
      return ShapeTreeTodoPalette.accentBlue.opacity(0.55)
    }
    return ShapeTreeTodoPalette.accentBlue.opacity(0.22)
  }

  private var composerBarBackground: Color {
    ShapeTreeTodoPalette.accentBlue.opacity(0.04)
  }

  private func sendIfValid() {
    guard !cannotSend else { return }
    Task {
      await onSend()
      isFocused = true
    }
  }
}
