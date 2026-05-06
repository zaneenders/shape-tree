import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import Testing

@testable import ShapeTree

@Suite
struct RouterTests {

  // MARK: - POST /sessions

  @Test func createSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.create-session")
    let router = buildRoutes(store: store, log: log)
    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = #"""
        {
            "model": "gemma4:e2b",
            "serverURL": "http://localhost:11434",
            "systemPrompt": "You are a helpful coding assistant."
        }
        """#
      try await client.execute(
        uri: "/sessions",
        method: .post,
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .ok)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = try decoder.decode(
          CreateSessionResponse.self,
          from: Data(buffer: response.body)
        )
        #expect(json.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(json.createdAt.timeIntervalSince1970 > 0)
      }
    }
  }

  @Test func createSessionWithInvalidURL() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.create-session-invalid-url")
    let router = buildRoutes(store: store, log: log)
    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = #"""
        {
            "model": "gemma4:e2b",
            "serverURL": "ftp://example.com",
            "systemPrompt": "Hello."
        }
        """#
      try await client.execute(
        uri: "/sessions",
        method: .post,
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  // MARK: - POST /sessions/:id/completions

  @Test func completionWithMalformedSessionId() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.completion-bad-id")
    let router = buildRoutes(store: store, log: log)
    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = #"{"message": "Hello"}"#
      try await client.execute(
        uri: "/sessions/not-a-uuid/completions",
        method: .post,
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func completionWithNonexistentSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.completion-not-found")
    let router = buildRoutes(store: store, log: log)
    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = #"{"message": "Hello"}"#
      let bogusId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
      try await client.execute(
        uri: "/sessions/\(bogusId.uuidString)/completions",
        method: .post,
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .notFound)
      }
    }
  }

}
