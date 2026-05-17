import ShapeTreeClient
import SwiftUI

// MARK: - Main shell tabs (Chat · Journal · Settings)

private enum ShapeTreeMainTab: String, CaseIterable, Identifiable {
  case chat = "Chat"
  case journal = "Journal"
  case settings = "Settings"

  var id: String { rawValue }

  var systemImage: String {
    switch self {
    case .chat: return "bubble.left.and.bubble.right.fill"
    case .journal: return "book.closed"
    case .settings: return "gearshape"
    }
  }
}

private struct ShapeTreeMainTabBar: View {
  @Binding var tab: ShapeTreeMainTab
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.colorScheme) private var colorScheme

  private var compact: Bool {
    horizontalSizeClass == .compact
  }

  private var trackFill: Color {
    Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.06)
  }

  private var selectionFill: Color {
    Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.1)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer(minLength: 0)
        HStack(spacing: 2) {
          ForEach(ShapeTreeMainTab.allCases) { item in
            Button {
              withAnimation(.easeInOut(duration: 0.18)) {
                tab = item
              }
            } label: {
              HStack(spacing: compact ? 5 : 7) {
                Image(systemName: item.systemImage)
                  .font(.system(size: compact ? 12 : 13, weight: .semibold))
                Text(item.rawValue)
                  .font(.system(size: compact ? 13 : 14, weight: .semibold))
              }
              .foregroundStyle(tab == item ? Color.primary : Color.secondary)
              .padding(.horizontal, compact ? 18 : 24)
              .padding(.vertical, compact ? 7 : 8)
              .background(
                Capsule(style: .continuous)
                  .fill(tab == item ? selectionFill : Color.clear)
              )
            }
            #if os(macOS)
            .buttonStyle(.borderless)
            #else
            .buttonStyle(.plain)
            #endif
          }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
          Capsule(style: .continuous)
            .fill(trackFill)
        )

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 2)
      #if os(macOS)
      .background(Color(nsColor: .windowBackgroundColor).opacity(0.98))
      #elseif canImport(UIKit)
      .background(Color(uiColor: UIColor.systemBackground))
      #else
      .background(Color.gray.opacity(0.08))
      #endif

      Divider()
        .allowsHitTesting(false)
    }
  }
}

// MARK: - Persistent connection status strip

private struct ConnectionStatusStrip: View {
  let state: ConnectionState
  let serverURL: String

  private var dotColor: Color {
    switch state {
    case .online: return .green
    case .unauthorized: return .orange
    case .offline: return .secondary
    }
  }

  private var label: String {
    switch state {
    case .online: return "online"
    case .unauthorized: return "not authorized"
    case .offline: return "offline"
    }
  }

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .frame(width: 7, height: 7)
        .foregroundStyle(dotColor)
      Text(label)
        .font(.caption2.weight(.medium))
        .foregroundStyle(dotColor)
      Spacer(minLength: 8)
      Text(serverURL)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 5)
    .background(Color.primary.opacity(0.03))

    Divider()
      .allowsHitTesting(false)
  }
}

// MARK: - Root shell

struct ShapeTreeChatView: View {
  /// Coalesces scroll signals to prevent multiple per-frame scrollToBottom calls.
  private struct ChatScrollDriver: Equatable {
    var messageCount: Int
    var lastScrollFingerprint: String?
    var isLoading: Bool
  }

  @Bindable var viewModel: ShapeTreeViewModel
  @State private var mainTab: ShapeTreeMainTab = .journal

  var body: some View {
    VStack(spacing: 0) {
      errorBanner(viewModel.journalError)
      errorBanner(viewModel.errorMessage)

      ShapeTreeMainTabBar(tab: $mainTab)

      ConnectionStatusStrip(
        state: viewModel.connectionState,
        serverURL: viewModel.serverURL)

      Group {
        switch mainTab {
        case .chat:
          assistantRoot
        case .journal:
          ShapeTreeJournalView(viewModel: viewModel)
        case .settings:
          ShapeTreeSettingsView(viewModel: viewModel)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .task {
      await viewModel.refreshJournalSubjects()
    }
    .onChange(of: viewModel.connectionState) { oldState, newState in
      guard oldState != .online, newState == .online else { return }
      Task { await viewModel.refreshJournalSubjects() }
    }
    #if os(macOS)
    .frame(minWidth: 540, minHeight: 460)
    #endif
  }

  @ViewBuilder
  private func errorBanner(_ message: String?) -> some View {
    if let message, !message.isEmpty {
      Text(message)
        .font(.caption)
        .foregroundStyle(.orange)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.12))
    }
  }

  private var assistantRoot: some View {
    VStack(spacing: 0) {
      headerView

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            if viewModel.messages.isEmpty {
              if viewModel.isOnline {
                emptyStateView
              } else {
                offlineStateView
              }
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
        .onChange(
          of: ChatScrollDriver(
            messageCount: viewModel.messages.count,
            lastScrollFingerprint: viewModel.messages.last?.scrollFingerprint,
            isLoading: viewModel.isLoading
          )
        ) { _, _ in
          Task { @MainActor in
            scrollToBottom(using: proxy)
          }
        }
      }

      if viewModel.isOnline {
        Divider()

        ShapeTreeChatInputView(
          text: $viewModel.inputText,
          onSend: { viewModel.sendMessage() },
          onInterrupt: {
            Task { await viewModel.interruptAgentTurn() }
          },
          isLoading: viewModel.isLoading
        )
      }
    }
  }

  // MARK: - Chat header

  private var headerView: some View {
    HStack {
      Text("Chat")
        .font(.headline)
      Spacer()
      Button("Reset", systemImage: "arrow.counterclockwise") {
        viewModel.reset()
      }
      .buttonStyle(.plain)
      .labelStyle(.titleAndIcon)
      .help("Clear messages and start a new session")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.bar)
  }

  // MARK: - Empty / offline states

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "tree")
        .font(.system(size: 48))
        .foregroundStyle(.tertiary)
      Text("ShapeTree")
        .font(.title2)
        .fontWeight(.semibold)
      Text("Send a message to start chatting.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, minHeight: 300)
  }

  private var offlineStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "wifi.slash")
        .font(.system(size: 48))
        .foregroundStyle(.tertiary)
      Text("Currently offline")
        .font(.title2)
        .fontWeight(.semibold)
      Text("Chat is unavailable while the server is unreachable.")
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
