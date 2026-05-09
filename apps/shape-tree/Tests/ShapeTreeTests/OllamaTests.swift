import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import ShapeTreeClient
import Testing

@testable import ShapeTree

// MARK: - Live Ollama integration

@Test func liveCompletion() async throws {
  let store = SessionStore()
  let log = Logger(label: "test.live-completion")
  let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
  let journalQuery = JournalQueryService(layout: layout, log: log)
  let jwtKeys = await JWTTestSupport.makeVerifierKeys()
  let router = buildRoutes(
    store: store,
    journalService: journal,
    journalQuery: journalQuery,
    jwtKeys: jwtKeys,
    log: log)
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
    let sessionId: String = try await client.execute(
      uri: "/sessions",
      method: .post,
      headers: try await JWTTestSupport.bearerHeaders(),
      body: ByteBuffer(string: createBody)
    ) { response in
      #expect(response.status == .ok)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let json = try decoder.decode(
        Components.Schemas.CreateSessionResponse.self,
        from: Data(buffer: response.body)
      )
      return json.id
    }

    // 2. Stream a completion.
    let completionBody = #"{"message": "Say hello in exactly one word."}"#
    try await client.execute(
      uri: "/sessions/\(sessionId)/completions/stream",
      method: .post,
      headers: try await JWTTestSupport.bearerHeaders(),
      body: ByteBuffer(string: completionBody)
    ) { response in
      #expect(response.status == .ok)

      let bodyText = String(buffer: response.body)
      let decoder = JSONDecoder()
      var assistant = ""
      for line in bodyText.split(separator: "\n", omittingEmptySubsequences: true) {
        let event = try decoder.decode(
          Components.Schemas.CompletionStreamEvent.self,
          from: Data(line.utf8)
        )
        if event.kind == .done {
          assistant = event.assistant_full_text ?? ""
          break
        }
      }
      #expect(!assistant.isEmpty)
    }
  }
}
