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
struct AuthorizedKeysTests {

  @Test func thumbprintIsStableAndWellFormed() {
    let kid = JWKThumbprint.thumbprint(
      crv: "P-256",
      x: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
      y: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
    )
    #expect(kid.count == 43)
    #expect(JWKThumbprint.isWellFormed(kid))
  }

  @Test func wellFormedRejectsBadShapes() {
    #expect(!JWKThumbprint.isWellFormed(""))
    #expect(!JWKThumbprint.isWellFormed("../etc/passwd"))
    #expect(!JWKThumbprint.isWellFormed("not-43-chars"))
    let padded = String(repeating: "A", count: 43) + "="
    #expect(!JWKThumbprint.isWellFormed(padded))
  }

  @Test func rejectsHS256TokenSignedWithSharedSecret() async throws {
    let log = Logger(label: "test.auth.alg-pin")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let hsKeys = JWTKeyCollection()
    await hsKeys.add(hmac: HMACKey(from: "any-old-secret"), digestAlgorithm: .sha256)
    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: fixture.kid),
      iat: IssuedAtClaim(value: Date()),
      exp: ExpirationClaim(value: Date().addingTimeInterval(900))
    )
    var header: JWTHeader = ["typ": "JWT", "alg": "HS256", "kid": .string(fixture.kid)]
    header.fields["dev"] = .string("test-device")
    let hsToken = try await hsKeys.sign(payload, header: header)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: [.authorization: "Bearer \(hsToken)"]
      ) { response in
        #expect(response.status == .unauthorized)
      }
    }
  }

  @Test func rejectsAlgNoneToken() async throws {
    let log = Logger(label: "test.auth.alg-none")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let header = #"{"alg":"none","typ":"JWT","kid":"\#(fixture.kid)"}"#
    let payload = #"{"sub":"\#(fixture.kid)","iat":0,"exp":9999999999}"#
    let h = Data(header.utf8).base64URLEncodedStringNoPadding()
    let p = Data(payload.utf8).base64URLEncodedStringNoPadding()
    let token = "\(h).\(p)."

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

  @Test func rejectsKidWithBadShape() async throws {
    let log = Logger(label: "test.auth.bad-kid")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    // Sign a *valid* ES256 JWT but lie about the kid in the header.
    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: fixture.kid),
      iat: IssuedAtClaim(value: Date()),
      exp: ExpirationClaim(value: Date().addingTimeInterval(900))
    )
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: fixture.privateKey)
    let header: JWTHeader = ["typ": "JWT", "alg": "ES256", "kid": "../etc/passwd"]
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

  @Test func rejectsUnknownButWellFormedKid() async throws {
    let log = Logger(label: "test.auth.unknown-kid")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    let strangerKid = String(repeating: "A", count: 43)
    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: strangerKid),
      iat: IssuedAtClaim(value: Date()),
      exp: ExpirationClaim(value: Date().addingTimeInterval(900))
    )
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: fixture.privateKey)
    let header: JWTHeader = ["typ": "JWT", "alg": "ES256", "kid": .string(strangerKid)]
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

  @Test func rejectsKeyfileSwappedUnderExistingFilename() async throws {
    let log = Logger(label: "test.auth.tampered-store")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()

    // Replace the contents of `<kid>.jwk` with a *different* P-256 public key
    // while keeping the filename identical. This simulates partial trust-store
    // tampering: the recomputed thumbprint won't match the filename.
    let other = ECDSA.PrivateKey<P256>()
    guard let params = other.publicKey.parameters else { return }
    let xRaw = Data(base64Encoded: params.x) ?? Data()
    let yRaw = Data(base64Encoded: params.y) ?? Data()
    let badJWK: [String: String] = [
      "kty": "EC",
      "crv": "P-256",
      "x": xRaw.base64URLEncodedStringNoPadding(),
      "y": yRaw.base64URLEncodedStringNoPadding(),
      "label": "intruder",
    ]
    let data = try JSONSerialization.data(withJSONObject: badJWK, options: [.sortedKeys])
    let file = fixture.directory.appendingPathComponent("\(fixture.kid).jwk", isDirectory: false)
    try data.write(to: file, options: [.atomic])

    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: try JWTTestSupport.bearerHeaders(fixture)
      ) { response in
        #expect(response.status == .unauthorized)
      }
    }
  }

  @Test func revokingKeyfileImmediatelyDeniesAccess() async throws {
    let log = Logger(label: "test.auth.revocation")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()
    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      log: log
    )
    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: try JWTTestSupport.bearerHeaders(fixture)
      ) { response in
        #expect(response.status == .ok)
      }

      let file = fixture.directory.appendingPathComponent("\(fixture.kid).jwk", isDirectory: false)
      try FileManager.default.removeItem(at: file)

      try await client.execute(
        uri: "/journal/subjects",
        method: .get,
        headers: try JWTTestSupport.bearerHeaders(fixture)
      ) { response in
        #expect(response.status == .unauthorized)
      }
    }
  }

  @Test func rejectsTokenWhereSubDoesNotMatchKid() async throws {
    let log = Logger(label: "test.auth.sub-binding")
    let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)

    // Enroll key A in the trust store.
    let fixtureA = try await JWTTestSupport.makeFixture()

    // Generate key B but do NOT enroll it — we only need its thumbprint.
    let fixtureB = try await JWTTestSupport.makeFixture()

    let router = buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixtureA.store,
      log: log
    )
    let app = Application(router: router)

    // Construct a JWT signed by key A, kid=A in the header (so the outer pin,
    // filesystem lookup, and signature verification all pass), but with
    // sub=B in the payload — the sub==kid guard should reject it.
    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: fixtureB.kid),
      iat: IssuedAtClaim(value: Date()),
      exp: ExpirationClaim(value: Date().addingTimeInterval(900))
    )
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: fixtureA.privateKey)
    let header: JWTHeader = [
      "typ": "JWT",
      "alg": "ES256",
      "kid": .string(fixtureA.kid),
    ]
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
}
