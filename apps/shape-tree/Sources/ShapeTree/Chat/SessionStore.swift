import Foundation
import ScribeCore

actor SessionStore {

  struct Session {
    let agent: ScribeAgent
    let createdAt: Date
  }

  private var sessions: [UUID: Session] = [:]

  func create(agent: ScribeAgent) -> UUID {
    let id = UUID()
    sessions[id] = Session(agent: agent, createdAt: Date())
    return id
  }

  func get(_ id: UUID) -> Session? {
    sessions[id]
  }

  /// Forwards to ``ScribeAgent/abort()`` — same contract as Scribe CLI
  /// ``ChatCoordinator/interrupt()``.
  func interrupt(_ id: UUID) {
    sessions[id]?.agent.abort()
  }
}
