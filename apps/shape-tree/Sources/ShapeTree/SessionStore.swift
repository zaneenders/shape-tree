import Foundation
import ScribeCore
import ScribeLLM

actor SessionStore {

  struct Session {
    let agent: ScribeAgent
    var messages: [Components.Schemas.ChatMessage]
    let createdAt: Date
  }

  private var sessions: [UUID: Session] = [:]

  func create(agent: ScribeAgent, systemPrompt: String) -> UUID {
    let id = UUID()
    sessions[id] = Session(
      agent: agent,
      messages: [
        .init(
          role: .system,
          content: systemPrompt,
          name: nil,
          toolCalls: nil,
          toolCallId: nil
        )
      ],
      createdAt: Date()
    )
    return id
  }

  /// Look up a session by ID.
  func get(_ id: UUID) -> Session? {
    sessions[id]
  }

  /// Update the message history for a session.
  func setMessages(_ id: UUID, messages: [Components.Schemas.ChatMessage]) {
    sessions[id]?.messages = messages
  }
}
