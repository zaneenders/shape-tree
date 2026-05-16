import Crypto
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import JWTKit
import Logging
import NIOCore
import ShapeTreeClient
import Testing

@testable import ShapeTree

@Suite
struct JWTReplayDefenseTests {

  @Test func freshThenReplayDecisions() async throws {
    let cache = JWTReplayCache()
    let kid = String(repeating: "A", count: 43)
    let jti = "jti-1"
    let exp = Date().addingTimeInterval(900)

    let first = try await cache.admit(kid: kid, jti: jti, exp: exp)
    let second = try await cache.admit(kid: kid, jti: jti, exp: exp)

    if case .fresh = first {} else { Issue.record("Expected first admission to be .fresh") }
    if case .replay = second {} else { Issue.record("Expected second admission to be .replay") }
  }

  @Test func differentKidsCanShareJti() async throws {
    let cache = JWTReplayCache()
    let kidA = String(repeating: "A", count: 43)
    let kidB = String(repeating: "B", count: 43)
    let jti = "shared"
    let exp = Date().addingTimeInterval(900)

    let a = try await cache.admit(kid: kidA, jti: jti, exp: exp)
    let b = try await cache.admit(kid: kidB, jti: jti, exp: exp)
    if case .fresh = a {} else { Issue.record("kidA admission should be fresh") }
    if case .fresh = b {} else { Issue.record("kidB admission should be fresh; key is (kid, jti)") }
  }

  @Test func expiredEntryIsReadmittedAfterTTL() async throws {
    let cache = JWTReplayCache(purgeInterval: 0)
    let kid = String(repeating: "A", count: 43)
    let jti = "expiring"
    let now = Date()

    let exp = now.addingTimeInterval(-1)
    let first = try await cache.admit(kid: kid, jti: jti, exp: exp, now: now)
    if case .fresh = first {} else { Issue.record("First admission should be fresh") }

    let later = now.addingTimeInterval(1)
    let second = try await cache.admit(kid: kid, jti: jti, exp: now.addingTimeInterval(900), now: later)
    if case .fresh = second {} else { Issue.record("Re-admission after exp should be fresh") }
  }

  @Test func capacityExceededThrows() async throws {
    let cache = JWTReplayCache(capacity: 2, purgeInterval: 3600)
    let exp = Date().addingTimeInterval(900)

    _ = try await cache.admit(kid: "k", jti: "a", exp: exp)
    _ = try await cache.admit(kid: "k", jti: "b", exp: exp)

    do {
      _ = try await cache.admit(kid: "k", jti: "c", exp: exp)
      Issue.record("Expected capacityExceeded")
    } catch JWTReplayCache.AdmissionError.capacityExceeded {}
  }

  @Test func sameTokenTwiceIsRejectedAsReplay() async throws {
    let log = Logger(label: "test.auth.replay")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let token = try JWTTestSupport.mintToken(fixture)
    let headers: HTTPFields = [.authorization: "Bearer \(token)"]

    try await app.test(.router) { client in
      try await client.execute(uri: "/journal/subjects", method: .get, headers: headers) { response in
        #expect(response.status == .ok)
      }
      try await client.execute(uri: "/journal/subjects", method: .get, headers: headers) { response in
        #expect(response.status == .unauthorized)
      }
    }
  }

  @Test func tokenMissingJtiIsRejected() async throws {
    let log = Logger(label: "test.auth.no-jti")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: fixture.kid),
      iat: IssuedAtClaim(value: Date()),
      exp: ExpirationClaim(value: Date().addingTimeInterval(900))
    )
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: fixture.privateKey)
    let header: JWTHeader = ["typ": "JWT", "alg": "ES256", "kid": .string(fixture.kid)]
    let token = try await keys.sign(payload, header: header)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: [.authorization: "Bearer \(token)"]
      ) { response in
        #expect(response.status == .unauthorized)
      }
    }
  }

  @Test func tokenWithStaleIatIsRejected() async throws {
    let log = Logger(label: "test.auth.iat-stale")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let oldIat = Date().addingTimeInterval(-2 * 60 * 60)
    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: fixture.kid),
      iat: IssuedAtClaim(value: oldIat),
      exp: ExpirationClaim(value: Date().addingTimeInterval(900)),
      jti: IDClaim(value: UUID().uuidString)
    )
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: fixture.privateKey)
    let header: JWTHeader = ["typ": "JWT", "alg": "ES256", "kid": .string(fixture.kid)]
    let token = try await keys.sign(payload, header: header)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: [.authorization: "Bearer \(token)"]
      ) { response in
        #expect(response.status == .unauthorized)
      }
    }
  }

  @Test func tokenWithFutureIatIsRejected() async throws {
    let log = Logger(label: "test.auth.iat-future")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let futureIat = Date().addingTimeInterval(10 * 60)
    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: fixture.kid),
      iat: IssuedAtClaim(value: futureIat),
      exp: ExpirationClaim(value: futureIat.addingTimeInterval(900)),
      jti: IDClaim(value: UUID().uuidString)
    )
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: fixture.privateKey)
    let header: JWTHeader = ["typ": "JWT", "alg": "ES256", "kid": .string(fixture.kid)]
    let token = try await keys.sign(payload, header: header)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: [.authorization: "Bearer \(token)"]
      ) { response in
        #expect(response.status == .unauthorized)
      }
    }
  }

  @Test func tokenWithMildlyFutureIatStillPasses() async throws {
    let log = Logger(label: "test.auth.iat-skew-tolerated")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let nearIat = Date().addingTimeInterval(10)
    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: fixture.kid),
      iat: IssuedAtClaim(value: nearIat),
      exp: ExpirationClaim(value: nearIat.addingTimeInterval(900)),
      jti: IDClaim(value: UUID().uuidString)
    )
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: fixture.privateKey)
    let header: JWTHeader = ["typ": "JWT", "alg": "ES256", "kid": .string(fixture.kid)]
    let token = try await keys.sign(payload, header: header)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: [.authorization: "Bearer \(token)"]
      ) { response in
        #expect(response.status == .ok)
      }
    }
  }
}
