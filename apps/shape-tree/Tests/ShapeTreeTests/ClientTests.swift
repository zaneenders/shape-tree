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

  @Test func createSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-create-session")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port, "Expected live server to have a port")

      let transport = AsyncHTTPClientTransport()
      let token = try JWTTestSupport.mintToken(fixture)
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: token)]
      )

      let response = try await api.createSession(
        body: .json(
          .init(
            systemPrompt: "You are a helpful coding assistant."
          )))

      let ok = try response.ok
      let json = try ok.body.json

      #expect(UUID(uuidString: json.id) != nil)
      #expect(json.createdAt.timeIntervalSince1970 > 0)
    }
  }

  @Test func listJournalSubjects() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-journal-subjects")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)
      let transport = AsyncHTTPClientTransport()
      let token = try JWTTestSupport.mintToken(fixture)
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: token)]
      )
      let response = try await api.listJournalSubjects()
      let ok = try response.ok
      let decoded = try ok.body.json
      #expect(decoded.subjects.contains { $0.id == "general" })
    }
  }

  @Test func appendJournalSubjectViaGeneratedClient() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-append-subject")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)
      let transport = AsyncHTTPClientTransport()
      let token = try JWTTestSupport.mintToken(fixture)
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: token)]
      )
      let response = try await api.appendJournalSubject(
        body: .json(.init(subject: "Ship Log"))
      )
      let ok = try response.ok
      let decoded = try ok.body.json
      #expect(decoded.subjects.contains { $0.label == "Ship Log" })
    }
  }

  @Test func completionStreamWithMalformedSessionId() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-stream-bad-id")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)

      let transport = AsyncHTTPClientTransport()
      let token = try JWTTestSupport.mintToken(fixture)
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: token)]
      )

      let response = try await api.runCompletionStream(
        path: .init(id: "not-a-uuid"),
        body: .json(.init(message: "Hello"))
      )

      let badRequest = try response.badRequest
      let errorJson = try badRequest.body.json
      #expect(!errorJson.error.message.isEmpty)
    }
  }

  @Test func completionStreamWithNonexistentSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-stream-not-found")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)

      let transport = AsyncHTTPClientTransport()
      let token = try JWTTestSupport.mintToken(fixture)
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: token)]
      )

      let bogusId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
      let response = try await api.runCompletionStream(
        path: .init(id: bogusId.uuidString),
        body: .json(.init(message: "Hello"))
      )

      let notFound = try response.notFound
      let errorJson = try notFound.body.json
      #expect(!errorJson.error.message.isEmpty)
    }
  }

  @Test func interruptSessionWithMalformedId() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-interrupt-bad-id")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)
      let transport = AsyncHTTPClientTransport()
      let token = try JWTTestSupport.mintToken(fixture)
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: token)]
      )

      let response = try await api.interruptSession(path: .init(id: "not-a-uuid"))
      let badRequest = try response.badRequest
      let errorJson = try badRequest.body.json
      #expect(!errorJson.error.message.isEmpty)
    }
  }

  @Test func interruptSessionWithNonexistentSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-interrupt-not-found")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)
      let transport = AsyncHTTPClientTransport()
      let token = try JWTTestSupport.mintToken(fixture)
      let api = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: token)]
      )

      let bogusId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
      let response = try await api.interruptSession(path: .init(id: bogusId.uuidString))
      let notFound = try response.notFound
      let errorJson = try notFound.body.json
      #expect(!errorJson.error.message.isEmpty)
    }
  }

  @Test func interruptSessionReturns204ForExistingSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.client-interrupt-204")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log)
    let app = Application(router: router)

    try await app.test(.live) { client in
      let port = try #require(client.port)
      let transport = AsyncHTTPClientTransport()
      let createToken = try JWTTestSupport.mintToken(fixture)
      let apiCreate = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: createToken)]
      )

      let created = try await apiCreate.createSession(body: .json(.init(systemPrompt: nil)))
      let ok = try created.ok
      let sessionId = try ok.body.json.id

      let interruptToken = try JWTTestSupport.mintToken(fixture)
      let apiInterrupt = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: interruptToken)]
      )

      // Fire a completion stream in a background task so the session is "busy"
      // when we call interrupt.  The stream will fail quickly (no LLM backend in
      // test), but that still exercises the concurrency path.
      let streamTask = Task {
        let streamToken = try JWTTestSupport.mintToken(fixture)
        let apiStream = Client(
          serverURL: URL(string: "http://localhost:\(port)")!,
          transport: transport,
          middlewares: [BearerAuthClientMiddleware(bearerToken: streamToken)]
        )
        _ = try? await apiStream.runCompletionStream(
          path: .init(id: sessionId),
          body: .json(.init(message: "Tell me a short story"))
        )
      }

      // Give the stream a moment to start before interrupting.
      try await Task.sleep(for: .milliseconds(50))

      let response = try await apiInterrupt.interruptSession(path: .init(id: sessionId))
      switch response {
      case .noContent:
        break
      default:
        Issue.record("Expected 204 noContent for interrupt on existing session")
      }

      // Wait for the stream task to settle so it doesn't keep the test alive.
      _ = try? await streamTask.value
    }
  }
}
