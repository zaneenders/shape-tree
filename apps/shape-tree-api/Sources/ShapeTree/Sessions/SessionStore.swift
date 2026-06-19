import Foundation
import ScribeCore

actor SessionStore {

  struct Session {
    let agent: ScribeAgent
    let createdAt: Date
    var history: [ScribeMessage]
  }

  private var sessions: [UUID: Session] = [:]

  func create(agent: ScribeAgent, systemPrompt: String) -> UUID {
    let id = UUID()
    sessions[id] = Session(
      agent: agent,
      createdAt: Date(),
      history: [ScribeMessage(role: .system, content: systemPrompt)]
    )
    return id
  }

  func get(_ id: UUID) -> Session? {
    sessions[id]
  }

  func appendMessages(_ id: UUID, _ messages: [ScribeMessage]) {
    guard !messages.isEmpty else { return }
    sessions[id]?.history.append(contentsOf: messages)
  }

  func interrupt(_ id: UUID) {
    sessions[id]?.agent.abort()
  }
}
