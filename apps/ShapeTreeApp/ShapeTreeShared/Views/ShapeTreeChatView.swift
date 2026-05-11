import ShapeTreeClient
import SwiftUI

#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Main shell tabs (Chat · Journal)

private enum ShapeTreeMainTab: String, CaseIterable, Identifiable {
  case chat = "Chat"
  case journal = "Journal"

  var id: String { rawValue }

  var systemImage: String {
    switch self {
    case .chat: return "bubble.left.and.bubble.right.fill"
    case .journal: return "book.closed"
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

/// Main chat view for the ShapeTree client app.
struct ShapeTreeChatView: View {
  @Bindable var viewModel: ShapeTreeViewModel
  @State private var mainTab: ShapeTreeMainTab = .chat
  @State private var showConnectionSettings = false
  @State private var connectionDraftURL = ""
  @State private var connectionDraftToken = ""
  @State private var connectionTokenFormatWarning: String?

  var body: some View {
    VStack(spacing: 0) {
      if let apiErr = viewModel.journalError, !apiErr.isEmpty {
        Text(apiErr)
          .font(.caption)
          .foregroundStyle(.orange)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity)
          .background(Color.orange.opacity(0.12))
      }

      if let chatErr = viewModel.errorMessage, !chatErr.isEmpty {
        Text(chatErr)
          .font(.caption)
          .foregroundStyle(.orange)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity)
          .background(Color.orange.opacity(0.12))
      }

      ShapeTreeMainTabBar(tab: $mainTab)

      Group {
        switch mainTab {
        case .chat:
          assistantRoot
        case .journal:
          ShapeTreeJournalView(viewModel: viewModel)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .task {
      await viewModel.refreshJournalSubjects()
    }
    .onChange(of: showConnectionSettings) { _, isPresented in
      guard isPresented else { return }
      connectionDraftURL = viewModel.serverURL
      connectionDraftToken = viewModel.apiBearerToken ?? ""
      connectionTokenFormatWarning = nil
    }
    .sheet(isPresented: $showConnectionSettings) {
      connectionSettingsSheet
    }
    #if os(macOS)
    .frame(minWidth: 540, minHeight: 460)
    #endif
  }

  private var connectionSettingsSheet: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Server URL", text: $connectionDraftURL)
            .textContentType(.URL)
            #if os(iOS)
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
            #endif
        } header: {
          Text("ShapeTree server")
        } footer: {
          Text(
            "Use http://127.0.0.1:PORT on this Mac or Simulator. On a physical iPhone, use your Mac's LAN IP (same Wi-Fi), not 127.0.0.1."
          )
        }

        Section {
          SecureField("Bearer JWT", text: $connectionDraftToken)
            #if os(iOS)
          .textContentType(.password)
            #endif
          if let hint = connectionTokenFormatWarning {
            Text(hint)
              .font(.footnote)
              .foregroundStyle(.red)
          }
        } header: {
          Text("API access token")
        } footer: {
          Text(
            "Paste a signed JWT (HS256), usually starting with eyJ and with two dots in the string—not jwt.secret, not JSON from shape-tree-config.json. Those stay on the server only; mint a short-lived token with the same secret. Optional \"Bearer \" prefix is OK."
          )
        }
      }
      .navigationTitle("Connection")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            connectionTokenFormatWarning = nil
            let url = connectionDraftURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let tok = connectionDraftToken.trimmingCharacters(in: .whitespacesAndNewlines)

            if !tok.isEmpty, let issue = ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue(tok) {
              connectionTokenFormatWarning = issue
              return
            }

            if !url.isEmpty, url != viewModel.serverURL {
              viewModel.serverURL = url
            }
            let normalized: String? = tok.isEmpty ? nil : ShapeTreeAPIClientMiddleware.normalizedBearerJWT(tok)
            if normalized != viewModel.apiBearerToken {
              viewModel.apiBearerToken = normalized
            }
            showConnectionSettings = false
            Task {
              await viewModel.refreshJournalSubjects()
            }
          }
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 400, minHeight: 280)
    #endif
  }

  private var assistantRoot: some View {
    VStack(spacing: 0) {
      headerView

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
        .onChange(of: viewModel.messages.last?.scrollFingerprint) { _, _ in
          scrollToBottom(using: proxy)
        }
        .onChange(of: viewModel.isLoading) { _, _ in
          scrollToBottom(using: proxy)
        }
      }

      Divider()

      ShapeTreeChatInputView(
        text: $viewModel.inputText,
        onSend: { viewModel.sendMessage() },
        isLoading: viewModel.isLoading
      )
    }
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
        Text("\(viewModel.serverURL)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      Button {
        showConnectionSettings = true
      } label: {
        Image(systemName: "network")
          .font(.system(size: 16))
      }
      .buttonStyle(.plain)
      .help("Server URL and API token")

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
      Text("Send a message to start chatting.")
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
        if arguments.trimmedForDisplay.isEmpty == false {
          toolCallSnippetBlock(label: "Arguments", body: arguments)
        }
        if output.trimmedForDisplay.isEmpty == false {
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
