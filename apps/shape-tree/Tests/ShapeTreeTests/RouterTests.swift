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
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
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
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders(fixture)
      ) { response in
        #expect(response.status == .ok)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.JournalSubjectsResponse.self,
          from: response.body.withUnsafeReadableBytes { Data($0) }
        )
        #expect(decoded.subjects.contains { $0.id == "general" })
      }
    }
  }

  @Test func appendJournalSubjectAddsLabelAndPersistsRoundTrip() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-subject-append")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let bodyPayload = #"{"subject":"Field Notes"}"#
      try await client.execute(
        uri: "/journal/subjects",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(fixture),
        body: ByteBuffer(string: bodyPayload)
      ) { response in
        #expect(response.status == .ok)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.JournalSubjectsResponse.self,
          from: response.body.withUnsafeReadableBytes { Data($0) }
        )
        #expect(decoded.subjects.contains { $0.label == "Field Notes" })
      }

      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders(fixture)
      ) { response in
        #expect(response.status == .ok)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.JournalSubjectsResponse.self,
          from: response.body.withUnsafeReadableBytes { Data($0) }
        )
        #expect(decoded.subjects.contains { $0.label == "Field Notes" })
      }
    }
  }

  @Test func appendJournalSubjectRejectsEmptyLabel() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-subject-empty")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let bodyPayload = #"{"subject":"   "}"#
      try await client.execute(
        uri: "/journal/subjects",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(fixture),
        body: ByteBuffer(string: bodyPayload)
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func appendJournalCommitsMarkdownBlock() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-append")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let filingDayKey = JournalPathCodec.journalDayKey(for: Date(), calendar: .current)
      let bodyPayload =
        "{\"subject_ids\":[\"general\"],\"body\":\"hello from test\",\"journal_day\":\"\(filingDayKey)\"}"
      try await client.execute(
        uri: "/journal/entries",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(fixture),
        body: ByteBuffer(string: bodyPayload)
      ) { response in
        #expect(response.status == .created)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.AppendJournalEntryResponse.self,
          from: response.body.withUnsafeReadableBytes { Data($0) }
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
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let appendBody =
        #"{"subject_ids":["general"],"body":"calendar api","created_at":"2026-05-06T15:00:00Z","journal_day":"26-05-06"}"#
      try await client.execute(
        uri: "/journal/entries",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(fixture),
        body: ByteBuffer(string: appendBody)
      ) { response in
        #expect(response.status == .created)
      }

      try await client.execute(
        uri: "/journal/entries?start_date=26-05-01&end_date=26-05-31",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders(fixture)
      ) { response in
        #expect(response.status == .ok)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.JournalEntriesSummariesResponse.self,
          from: response.body.withUnsafeReadableBytes { Data($0) }
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
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let filingDayKey = JournalPathCodec.journalDayKey(for: Date(), calendar: .current)

    try await app.test(.router) { client in
      let appendBody =
        "{\"subject_ids\":[\"general\"],\"body\":\"detail line\",\"created_at\":\"2026-07-01T12:00:00Z\",\"journal_day\":\"\(filingDayKey)\"}"
      try await client.execute(
        uri: "/journal/entries",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(fixture),
        body: ByteBuffer(string: appendBody)
      ) { response in
        #expect(response.status == .created)
      }

      try await client.execute(
        uri: "/journal/entries/\(filingDayKey)",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders(fixture)
      ) { response in
        #expect(response.status == .ok)
        let decoded = try JSONDecoder().decode(
          Components.Schemas.JournalEntryDetailResponse.self,
          from: response.body.withUnsafeReadableBytes { Data($0) }
        )
        #expect(decoded.date == filingDayKey)
        #expect(decoded.content.contains("detail line"))
      }
    }
  }

  @Test func getJournalEntryDetailNotFound() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.journal-detail-missing")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/entries/77-07-07",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders(fixture)
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
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/entries?start_date=26-05-10&end_date=26-05-01",
        method: .get,
        headers: try await JWTTestSupport.bearerHeaders(fixture)
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
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
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
        headers: try await JWTTestSupport.bearerHeaders(fixture),
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .ok)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let json = try decoder.decode(
          Components.Schemas.CreateSessionResponse.self,
          from: response.body.withUnsafeReadableBytes { Data($0) }
        )
        #expect(UUID(uuidString: json.id) != nil)
        #expect(json.createdAt.timeIntervalSince1970 > 0)
      }
    }
  }

  // MARK: - POST /sessions/{id}/completions/stream

  @Test func completionStreamWithMalformedSessionId() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.completion-bad-id")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = #"{"message": "Hello"}"#
      try await client.execute(
        uri: "/sessions/not-a-uuid/completions/stream",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(fixture),
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func completionStreamWithNonexistentSession() async throws {
    let store = SessionStore()
    let log = Logger(label: "test.completion-not-found")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let journalQuery = JournalQueryService(layout: layout, log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: store,
      journalService: journal,
      journalQuery: journalQuery,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = #"{"message": "Hello"}"#
      let bogusId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
      try await client.execute(
        uri: "/sessions/\(bogusId.uuidString)/completions/stream",
        method: .post,
        headers: try await JWTTestSupport.bearerHeaders(fixture),
        body: ByteBuffer(string: body)
      ) { response in
        #expect(response.status == .notFound)
      }
    }
  }

}
