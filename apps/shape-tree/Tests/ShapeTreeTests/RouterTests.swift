import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import ShapeTreeClient
import Testing

@testable import ShapeTree

@Suite
struct RouterTests {

  // MARK: - Auth

  @Test func rejectsMissingAuthorization() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.jwt-missing")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get
      ) { response in
        #expect(response.status == .unauthorized)
      }
    }
  }

  // MARK: - Journal

  @Test func listJournalSubjectsIncludesDefaultCatalog() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-subjects")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders()
      ) { response in
        #expect(response.status == .ok)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.JournalSubjectsResponse.self,
          from: Data(buffer: response.body)
        )
        #expect(decoded.subjects.contains { $0.id == "general" })
      }
    }
  }

  @Test func appendJournalCommitsMarkdownBlock() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-append")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let bodyPayload = #"{"subject_ids":["general"],"body":"hello from test"}"#
      try await client.execute(
        uri: "/journal/entries",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(),
        body: ByteBuffer(string: bodyPayload)
      ) { response in
        #expect(response.status == .created)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.AppendJournalEntryResponse.self,
          from: Data(buffer: response.body)
        )
        var entryURL = layout.journalRepoRoot
        for fragment in decoded.journal_relative_path.split(separator: "/") where !fragment.isEmpty {
          entryURL = entryURL.appendingPathComponent(String(fragment), isDirectory: false)
        }
        let text = try String(contentsOf: entryURL, encoding: .utf8)
        #expect(text.contains("# General"))
        #expect(text.contains("hello from test"))
        #expect(text.contains("-----"))
      }
    }
  }

  @Test func listJournalEntrySummariesAfterAppend() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-list")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let appendBody =
        #"{"subject_ids":["general"],"body":"calendar api","created_at":"2026-05-06T15:00:00Z"}"#
      try await client.execute(
        uri: "/journal/entries",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(),
        body: ByteBuffer(string: appendBody)
      ) { response in
        #expect(response.status == .created)
      }

      try await client.execute(
        uri: "/journal/entries?start_date=26-05-01&end_date=26-05-31",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders()
      ) { response in
        #expect(response.status == .ok)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.JournalEntriesSummariesResponse.self,
          from: Data(buffer: response.body)
        )
        let hit = decoded.entries.first { $0.date == "26-05-06" }
        #expect(hit != nil)
        #expect(hit!.word_count > 0)
      }
    }
  }

  @Test func getJournalEntryDetailAfterAppend() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-detail")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let appendBody =
        #"{"subject_ids":["general"],"body":"detail line","created_at":"2026-07-01T12:00:00Z"}"#
      try await client.execute(
        uri: "/journal/entries",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(),
        body: ByteBuffer(string: appendBody)
      ) { response in
        #expect(response.status == .created)
      }

      try await client.execute(
        uri: "/journal/entries/26-07-01",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders()
      ) { response in
        #expect(response.status == .ok)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.JournalEntryDetailResponse.self,
          from: Data(buffer: response.body)
        )
        #expect(decoded.date == "26-07-01")
        #expect(decoded.content.contains("detail line"))
      }
    }
  }

  @Test func getJournalEntryDetailNotFound() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-detail-missing")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/entries/77-07-07",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders()
      ) { response in
        #expect(response.status == .notFound)
      }
    }
  }

  @Test func listJournalEntrySummariesRejectsBadRange() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-list-bad")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/entries?start_date=26-05-10&end_date=26-05-01",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders()
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  // MARK: - POST /sessions

  @Test func createSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.create-session")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
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
        headers: try await JWTTestSupport.bearerHeaders(),
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .ok)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = try decoder.decode(
          Components.Schemas.CreateSessionResponse.self,
          from: Data(buffer: response.body)
        )
        #expect(UUID(uuidString: json.id) != nil)
        #expect(json.createdAt.timeIntervalSince1970 > 0)
      }
    }
  }

  // MARK: - POST /sessions/{id}/completions

  @Test func completionWithMalformedSessionId() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.completion-bad-id")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = #"{"message": "Hello"}"#
      try await client.execute(
        uri: "/sessions/not-a-uuid/completions",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(),
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func completionWithNonexistentSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.completion-not-found")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let jwtKeys = await JWTTestSupport.makeVerifierKeys()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      jwtKeys: jwtKeys,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = #"{"message": "Hello"}"#
      let bogusId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
      try await client.execute(
        uri: "/sessions/\(bogusId.uuidString)/completions",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(),
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .notFound)
      }
    }
  }

}
