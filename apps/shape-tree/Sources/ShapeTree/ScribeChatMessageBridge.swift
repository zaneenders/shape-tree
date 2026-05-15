import ScribeCore
import ScribeLLM

extension ScribeMessage {
  func toComponentsChatMessage() -> Components.Schemas.ChatMessage {
    let role: Components.Schemas.ChatMessage.RolePayload = {
      switch self.role {
      case .system: return .system
      case .user: return .user
      case .assistant: return .assistant
      case .tool: return .tool
      }
    }()
    let calls = toolCalls?.map { tc in
      Components.Schemas.AssistantToolCall(
        id: tc.id,
        _type: "function",
        function: .init(name: tc.name, arguments: tc.arguments)
      )
    }
    return Components.Schemas.ChatMessage(
      role: role,
      content: content,
      name: name,
      toolCalls: calls,
      toolCallId: toolCallId,
      reasoningContent: reasoning
    )
  }
}
