import SwiftUI

/// Single chat row. Renders user input as one rounded bubble and assistant turns as a vertical
/// stack of timeline blocks (`reasoning`, `toolRound`, `toolCall`, `answer`).
struct ShapeTreeMessageBubble: View {
  let message: ChatMessage
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .top) {
      if message.isUser { Spacer() }

      Group {
        if message.isUser {
          userBubble
        } else {
          assistantBubbles
        }
      }
      .frame(maxWidth: 600, alignment: message.isUser ? .trailing : .leading)

      if !message.isUser { Spacer() }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }

  private var userBubble: some View {
    Text(message.content)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.accentColor)
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .textSelection(.enabled)
  }

  private var assistantBubbles: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(message.assistantBlocks) { block in
        timelineBlock(block)
      }
    }
  }

  @ViewBuilder
  private func timelineBlock(_ block: AssistantTimelineBlock) -> some View {
    switch block.kind {
    case .reasoning(let text) where text.trimmedForDisplay.isEmpty:
      EmptyView()
    case .reasoning(let text):
      thinkingBlock(text)

    case .toolRound(let round, let names) where names.isEmpty && round <= 0:
      EmptyView()
    case .toolRound(let round, let names):
      toolRoundBlock(round: round, toolNames: names)

    case .toolCall(let name, let arguments, let output):
      toolCallBlock(toolName: name, arguments: arguments, output: output)

    case .answer(let text) where text.trimmedForDisplay.isEmpty:
      EmptyView()
    case .answer(let text):
      answerBlock(text)
    }
  }

  private func toolRoundBlock(round: Int, toolNames: [String]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "square.stack.3d.down.forward.fill")
          .font(.caption.weight(.semibold))
          .symbolRenderingMode(.hierarchical)
        Text(round > 0 ? "Tool round \(round)" : "Tools")
          .font(.caption.weight(.semibold))
      }
      .foregroundStyle(.secondary)

      FlowingNameChips(names: toolNames)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.teal.opacity(colorScheme == .dark ? 0.18 : 0.1))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.teal.opacity(colorScheme == .dark ? 0.45 : 0.35), lineWidth: 1)
    )
  }

  private func toolCallBlock(toolName: String, arguments: String, output: String) -> some View {
    let title = toolName.trimmedForDisplay.isEmpty ? "Tool" : toolName.trimmedForDisplay

    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "wrench.and.screwdriver.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.teal)
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
        Spacer(minLength: 0)
      }

      if arguments.trimmedForDisplay.isEmpty, output.trimmedForDisplay.isEmpty {
        Text("Completed")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        if !arguments.trimmedForDisplay.isEmpty {
          toolCallSnippetBlock(label: "Arguments", body: arguments)
        }
        if !output.trimmedForDisplay.isEmpty {
          toolCallSnippetBlock(label: "Output", body: output)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.cyan.opacity(colorScheme == .dark ? 0.12 : 0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.cyan.opacity(colorScheme == .dark ? 0.4 : 0.28), lineWidth: 1)
    )
  }

  private func toolCallSnippetBlock(label: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(body)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04)))
  }

  private func thinkingBlock(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: "sparkles")
          .font(.caption.weight(.semibold))
          .symbolRenderingMode(.hierarchical)
        Text("Thinking")
          .font(.caption.weight(.semibold))
      }
      .foregroundStyle(.secondary)

      Text(text)
        .font(.callout)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)
        .textSelection(.enabled)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
    )
  }

  private func answerBlock(_ text: String) -> some View {
    Text(text)
      .font(.body)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .foregroundStyle(.primary)
      .background(Color.accentColor.opacity(0.15))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .textSelection(.enabled)
      .multilineTextAlignment(.leading)
  }
}

private struct FlowingNameChips: View {
  let names: [String]

  private let columns = [GridItem(.adaptive(minimum: 52), spacing: 8, alignment: .leading)]

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
      ForEach(Array(names.enumerated()), id: \.offset) { _, name in
        Text(name)
          .font(.caption.weight(.medium))
          .foregroundStyle(.primary)
          .lineLimit(2)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.09)))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension String {
  fileprivate var trimmedForDisplay: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
