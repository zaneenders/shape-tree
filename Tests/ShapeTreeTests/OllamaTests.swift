import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import Testing

@testable import ShapeTree

// MARK: - Live Ollama integration

@Test func liveCompletion() async throws {
  let store = SessionStore()
  let log = Logger(label: "test.live-completion")
  let router = buildRoutes(store: store, log: log)
  let app = Application(router: router)

  try await app.test(.router) { client in
    // 1. Create a session pointing at the local Ollama instance.
    let createBody = #"""
      {
          "model": "gemma4:e2b",
          "serverURL": "http://localhost:11434",
          "systemPrompt": "Reply concisely."
      }
      """#
    let sessionId: UUID = try await client.execute(
      uri: "/sessions",
      method: .post,
      body: ByteBuffer(string: createBody)
    ) { response in
      #expect(response.status == .ok)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let json = try decoder.decode(
        CreateSessionResponse.self,
        from: Data(buffer: response.body)
      )
      return json.id
    }

    // 2. Run a completion.
    let completionBody = #"{"message": "Say hello in exactly one word."}"#
    try await client.execute(
      uri: "/sessions/\(sessionId.uuidString)/completions",
      method: .post,
      body: ByteBuffer(string: completionBody)
    ) { response in
      #expect(response.status == .ok)

      let decoder = JSONDecoder()
      let json = try decoder.decode(
        CompletionResponse.self,
        from: Data(buffer: response.body)
      )
      #expect(!json.assistant.isEmpty)
    }
  }
}
