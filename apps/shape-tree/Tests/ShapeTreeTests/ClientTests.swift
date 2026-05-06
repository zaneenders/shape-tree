import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import OpenAPIAsyncHTTPClient
import ShapeTreeClient
import Testing

@testable import ShapeTree

@Suite
struct ClientTests {

  // MARK: - POST /sessions (via generated client)

  @Test func createSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-create-session")
    let router = buildRoutes(store: store, log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port, "Expected live server to have a port")

      let transport = AsyncHTTPClientTransport()
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport
      )

      let response = try await api.createSession(
        body: .json(
          .init(
            systemPrompt: "You are a helpful coding assistant."
          )))

      let ok = try response.ok
      let json = try ok.body.json

      // id should be a valid UUID string
      #expect(UUID(uuidString: json.id) != nil)
      #expect(json.createdAt.timeIntervalSince1970 > 0)
    }
  }

  // MARK: - POST /sessions/{id}/completions

  @Test func completionWithMalformedSessionId() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-bad-id")
    let router = buildRoutes(store: store, log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)

      let transport = AsyncHTTPClientTransport()
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport
      )

      let response = try await api.runCompletion(
        path: .init(id: "not-a-uuid"),
        body: .json(.init(message: "Hello"))
      )

      let badRequest = try response.badRequest
      let errorJson = try badRequest.body.json
      #expect(!errorJson.error.message.isEmpty)
    }
  }

  @Test func completionWithNonexistentSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-not-found")
    let router = buildRoutes(store: store, log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)

      let transport = AsyncHTTPClientTransport()
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport
      )

      let bogusId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
      let response = try await api.runCompletion(
        path: .init(id: bogusId.uuidString),
        body: .json(.init(message: "Hello"))
      )

      let notFound = try response.notFound
      let errorJson = try notFound.body.json
      #expect(!errorJson.error.message.isEmpty)
    }
  }
}
