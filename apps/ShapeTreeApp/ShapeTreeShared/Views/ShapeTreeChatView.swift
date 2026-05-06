import SwiftUI

/// Main chat view for the ShapeTree client app.
struct ShapeTreeChatView: View {
  @Bindable var viewModel: ShapeTreeViewModel

  var body: some View {
    VStack(spacing: 0) {
      // Header
      headerView

      // Messages
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            if viewModel.messages.isEmpty {
              emptyStateView
            } else {
              ForEach(viewModel.messages) { message in
                ShapeTreeMessageBubble(message: message)
                  .id(message.id)
              }
              if viewModel.isLoading {
                HStack {
                  ProgressView()
                    .padding(.vertical, 12)
                  Text("Thinking…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Spacer()
                }
                .padding(.horizontal, 16)
                .id("loading")
              }
            }
          }
          .padding(.vertical, 8)
        }
        .onChange(of: viewModel.messages.count) { _, _ in
          scrollToBottom(using: proxy)
        }
        .onChange(of: viewModel.messages.last?.content) { _, _ in
          scrollToBottom(using: proxy)
        }
        .onChange(of: viewModel.isLoading) { _, _ in
          scrollToBottom(using: proxy)
        }
      }

      Divider()

      // Input
      ShapeTreeChatInputView(
        text: $viewModel.inputText,
        onSend: { viewModel.sendMessage() },
        isLoading: viewModel.isLoading
      )
    }
    #if os(macOS)
    .frame(minWidth: 500, minHeight: 400)
    #endif
  }

  // MARK: - Header

  private var headerView: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text("ShapeTree")
            .font(.headline)
          Circle()
            .frame(width: 6, height: 6)
            .foregroundStyle(.green)
        }
        Text("\(viewModel.model) — \(viewModel.serverURL)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      Button {
        viewModel.reset()
      } label: {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 16))
      }
      .buttonStyle(.plain)
      .help("New session")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.bar)
  }

  // MARK: - Empty state

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "tree")
        .font(.system(size: 48))
        .foregroundStyle(.tertiary)
      Text("ShapeTree")
        .font(.title2)
        .fontWeight(.semibold)
      Text("Send a message to start chatting with \(viewModel.model).")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, minHeight: 300)
  }

  // MARK: - Helpers

  private func scrollToBottom(using proxy: ScrollViewProxy) {
    if viewModel.isLoading {
      withAnimation(.easeOut(duration: 0.2)) {
        proxy.scrollTo("loading", anchor: .bottom)
      }
    } else if let lastId = viewModel.messages.last?.id {
      withAnimation(.easeOut(duration: 0.2)) {
        proxy.scrollTo(lastId, anchor: .bottom)
      }
    }
  }
}

// MARK: - Message Bubble

struct ShapeTreeMessageBubble: View {
  let message: ChatMessage

  var body: some View {
    HStack {
      if message.isUser { Spacer() }

      Text(message.content)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(message.isUser ? Color.accentColor : Color.accentColor.opacity(0.15))
        .foregroundColor(message.isUser ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .textSelection(.enabled)
        .frame(maxWidth: 600, alignment: message.isUser ? .trailing : .leading)

      if !message.isUser { Spacer() }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }
}
