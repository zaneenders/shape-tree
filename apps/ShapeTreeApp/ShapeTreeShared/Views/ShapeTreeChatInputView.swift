import SwiftUI

struct ShapeTreeChatInputView: View {
  @Binding var text: String
  let onSend: () -> Void
  let isLoading: Bool
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(alignment: .bottom, spacing: 12) {
      TextField("Message", text: $text, axis: .vertical)
        .lineLimit(1...5)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .focused($isFocused)
        .disabled(isLoading)
        .onKeyPress(.return) {
          sendIfValid()
          return .handled
        }

      Button(action: sendIfValid) {
        Image(systemName: "arrow.up.circle.fill")
          .resizable()
          .frame(width: 32, height: 32)
          .foregroundColor(isSendDisabled ? .gray : .accentColor)
      }
      .buttonStyle(.plain)
      .disabled(isSendDisabled)
      .keyboardShortcut(.return, modifiers: [.command])
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.accentColor.opacity(0.05))
  }

  private var isSendDisabled: Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
  }

  private func sendIfValid() {
    guard !isSendDisabled else { return }
    onSend()
    isFocused = true
  }
}
