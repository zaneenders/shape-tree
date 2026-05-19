import SwiftUI

#if os(macOS)
import AppKit

/// macOS `TextField` in a `Form` often ignores SwiftUI `onKeyPress` for Tab; use `NSTextField` instead.
struct ShapeTreeTodoBreakDownStepField: View {
  @Binding var text: String
  let focusGeneration: Int
  let onTab: () -> Void
  let onShiftTab: () -> Void
  let onBreakDown: () -> Void

  private var trimmed: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    HStack(spacing: 8) {
      MacBreakDownTextField(
        text: $text,
        placeholder: "Subtask",
        focusGeneration: focusGeneration,
        onTab: onTab,
        onShiftTab: onShiftTab
      )
      .frame(maxWidth: .infinity, minHeight: 22)

      if !trimmed.isEmpty {
        Button(action: onBreakDown) {
          Image(systemName: "list.bullet.indent")
            .font(.body)
            .foregroundStyle(ShapeTreeTodoPalette.accentBlue)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Break down \(trimmed)")
        .help("Save these steps, then break down “\(trimmed)”")
      }
    }
  }
}

private struct MacBreakDownTextField: NSViewRepresentable {
  @Binding var text: String
  let placeholder: String
  let focusGeneration: Int
  let onTab: () -> Void
  let onShiftTab: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, onTab: onTab, onShiftTab: onShiftTab)
  }

  func makeNSView(context: Context) -> NSTextField {
    let field = NSTextField()
    field.stringValue = text
    field.placeholderString = placeholder
    field.isBordered = false
    field.isBezeled = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = .systemFont(ofSize: NSFont.systemFontSize)
    field.delegate = context.coordinator
    field.lineBreakMode = .byTruncatingTail
    return field
  }

  func updateNSView(_ field: NSTextField, context: Context) {
    if field.stringValue != text {
      field.stringValue = text
    }
    if field.placeholderString != placeholder {
      field.placeholderString = placeholder
    }
    if focusGeneration > 0, focusGeneration != context.coordinator.appliedFocusGeneration {
      context.coordinator.appliedFocusGeneration = focusGeneration
      context.coordinator.focus(field)
    }
  }

  final class Coordinator: NSObject, NSTextFieldDelegate {
    @Binding var text: String
    let onTab: () -> Void
    let onShiftTab: () -> Void
    var appliedFocusGeneration = 0

    init(text: Binding<String>, onTab: @escaping () -> Void, onShiftTab: @escaping () -> Void) {
      _text = text
      self.onTab = onTab
      self.onShiftTab = onShiftTab
    }

    func focus(_ field: NSTextField) {
      DispatchQueue.main.async { [weak field] in
        guard let field, let window = field.window else { return }
        window.makeFirstResponder(field)
        if let editor = field.currentEditor() {
          editor.selectedRange = NSRange(location: field.stringValue.utf16.count, length: 0)
        }
      }
    }

    func controlTextDidChange(_ obj: Notification) {
      guard let field = obj.object as? NSTextField else { return }
      text = field.stringValue
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
      switch commandSelector {
      case #selector(NSResponder.insertTab(_:)):
        onTab()
        return true
      case #selector(NSResponder.insertBacktab(_:)):
        onShiftTab()
        return true
      case #selector(NSResponder.insertNewline(_:)):
        onTab()
        return true
      default:
        return false
      }
    }
  }
}

#else

struct ShapeTreeTodoBreakDownStepField: View {
  @Binding var text: String
  var focusedStepIndex: FocusState<Int?>.Binding
  let index: Int
  let requestFocus: Bool
  let onTab: () -> Void
  let onShiftTab: () -> Void
  let onBreakDown: () -> Void

  private var trimmed: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    HStack(spacing: 8) {
      TextField("", text: $text, prompt: Text("Subtask").foregroundStyle(.tertiary))
        .focused(focusedStepIndex, equals: index)
        .onKeyPress { keyPress in
          guard keyPress.key == .tab else { return .ignored }
          if keyPress.modifiers.contains(.shift) {
            onShiftTab()
          } else {
            onTab()
          }
          return .handled
        }

      if !trimmed.isEmpty {
        Button(action: onBreakDown) {
          Image(systemName: "list.bullet.indent")
            .font(.body)
            .foregroundStyle(ShapeTreeTodoPalette.accentBlue)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Break down \(trimmed)")
      }
    }
    .onChange(of: requestFocus) { _, shouldFocus in
      guard shouldFocus else { return }
      focusedStepIndex.wrappedValue = index
    }
  }
}

#endif
