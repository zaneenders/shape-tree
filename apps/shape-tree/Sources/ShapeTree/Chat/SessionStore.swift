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
}
