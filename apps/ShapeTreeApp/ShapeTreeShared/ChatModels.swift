import Foundation

// MARK: - Chat models

public struct AssistantTimelineBlock: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let kind: Kind

  public enum Kind: Equatable, Sendable {
    case reasoning(String)
    case toolRound(round: Int, toolNames: [String])
    case toolCall(toolName: String, arguments: String, output: String)
    case answer(String)
  }

  public init(id: UUID = UUID(), kind: Kind) {
    self.id = id
    self.kind = kind
  }

  var scrollFingerprintPiece: String {
    switch kind {
    case .reasoning(let s): return "r:\(s)"
    case .answer(let s): return "a:\(s)"
    case .toolRound(let r, let names): return "tr:\(r):\(names.joined(separator: "|"))"
    case .toolCall(let name, let args, let output): return "tc:\(name)|\(args)|\(output)"
    }
  }

  var isVisuallyEmpty: Bool {
    switch kind {
    case .reasoning(let s), .answer(let s):
      return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .toolRound(_, let names):
      return names.isEmpty
    case .toolCall(let name, let args, let output):
      return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && args.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
}

public struct ChatMessage: Identifiable, Equatable {
  public let id: UUID
  public let isUser: Bool
  public let content: String
  public let assistantBlocks: [AssistantTimelineBlock]

  public init(id: UUID = UUID(), content: String, isUser: Bool) {
    self.id = id
    self.isUser = isUser
    self.content = content
    self.assistantBlocks = []
  }

  public init(id: UUID, assistantBlocks: [AssistantTimelineBlock]) {
    self.id = id
    self.isUser = false
    self.content = ""
    self.assistantBlocks = assistantBlocks
  }

  public var scrollFingerprint: String {
    if isUser { return content }
    return assistantBlocks.map(\.scrollFingerprintPiece).joined(separator: "\u{1e}")
  }

  var isAssistantPlaceholderVisuallyEmpty: Bool {
    assistantBlocks.isEmpty || assistantBlocks.allSatisfy(\.isVisuallyEmpty)
  }
}

// MARK: - Errors

enum AppError: LocalizedError {
  case invalidURL(String)
  case server(String)

  var errorDescription: String? {
    switch self {
    case .invalidURL(let url): return "Invalid server URL: \(url)"
    case .server(let message): return message
    }
  }
}
