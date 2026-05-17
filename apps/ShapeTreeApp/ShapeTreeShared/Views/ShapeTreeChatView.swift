import ShapeTreeClient
import SwiftUI

// MARK: - Main shell tabs (Scribe · Journal · Settings)

private enum ShapeTreeMainTab: String, CaseIterable, Identifiable {
  case scribe = "Scribe"
  case journal = "Journal"
  case settings = "Settings"

  var id: String { rawValue }

  var systemImage: String {
    switch self {
    case .scribe: return "bubble.left.and.bubble.right.fill"
    case .journal: return "book.closed"
    case .settings: return "gearshape"
    }
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
      toolbar
      Group {
        switch mainTab {
        case .scribe:
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

  // MARK: - Toolbar (tabs + status + URL in one row)

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var toolbar: some View {
    let compact = horizontalSizeClass == .compact

    return VStack(spacing: 0) {
      HStack(spacing: 0) {
        connectionStatusLabel(compact: compact)
        Spacer()
        tabPicker(compact: compact)
        Spacer()
        if !compact {
          serverURLText
        }
      }
      .padding(.horizontal, compact ? 8 : 12)
      .padding(.vertical, compact ? 4 : 6)

      Divider()
        .allowsHitTesting(false)
    }
    .background(.bar)
  }

  private func connectionStatusLabel(compact: Bool) -> some View {
    HStack(spacing: 5) {
      Circle()
        .frame(width: 7, height: 7)
        .foregroundStyle(statusDotColor)
      if !compact {
        Text(statusLabelText)
          .font(.caption2.weight(.medium))
          .foregroundStyle(statusDotColor)
      }
    }
    .frame(minWidth: compact ? 24 : 80, alignment: .leading)
  }

  private var statusDotColor: Color {
    switch viewModel.connectionState {
    case .online: return .green
    case .unauthorized: return .orange
    case .offline: return .secondary
    }
  }

  private var statusLabelText: String {
    switch viewModel.connectionState {
    case .online: return "online"
    case .unauthorized: return "not authorized"
    case .offline: return "offline"
    }
  }

  private func tabPicker(compact: Bool) -> some View {
    HStack(spacing: 2) {
      ForEach(ShapeTreeMainTab.allCases) { item in
        Button {
          withAnimation(.easeInOut(duration: 0.18)) {
            mainTab = item
          }
        } label: {
          HStack(spacing: compact ? 4 : 6) {
            Image(systemName: item.systemImage)
              .font(.system(size: compact ? 11 : 12, weight: .semibold))
            Text(item.rawValue)
              .font(.system(size: compact ? 12 : 13, weight: .semibold))
          }
          .foregroundStyle(mainTab == item ? Color.primary : Color.secondary)
          .padding(.horizontal, compact ? 12 : 18)
          .padding(.vertical, compact ? 4 : 6)
          .background(
            Capsule(style: .continuous)
              .fill(mainTab == item ? Color.primary.opacity(0.1) : Color.clear)
          )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, compact ? 2 : 4)
    .padding(.vertical, compact ? 2 : 3)
    .background(
      Capsule(style: .continuous)
        .fill(Color.primary.opacity(0.06))
    )
  }

  private var serverURLText: some View {
    Text(viewModel.serverURL)
      .font(.caption2)
      .foregroundStyle(.tertiary)
      .lineLimit(1)
      .truncationMode(.middle)
      .frame(minWidth: 80, alignment: .trailing)
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

  private var headerView: some View {
    HStack {
      Text("Scribe")
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
