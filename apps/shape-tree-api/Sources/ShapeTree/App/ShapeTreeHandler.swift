import Foundation
import Logging
import OpenAPIHummingbird
import OpenAPIRuntime
import ScribeCore
import ShapeTreeClient

/// Implements the generated `APIProtocol` produced by swift-openapi-generator.
/// Uses generated request/response types from the `ShapeTreeClient` module
/// so the client and server stay exactly in sync with `openapi.yaml`.
struct ShapeTreeHandler: APIProtocol, Sendable {

  let store: SessionStore
  let journalStore: JournalStore
  let log: Logger
  let llmURL: String
  let agentModel: String
  let systemPrompt: String
  let llmToken: String?
  let contextWindow: Int
  let contextWindowThreshold: Double
  let workingDirectory: String

  // MARK: GET /ping

  func ping(_ input: Operations.ping.Input) async throws -> Operations.ping.Output {
    .noContent(.init())
  }
}
