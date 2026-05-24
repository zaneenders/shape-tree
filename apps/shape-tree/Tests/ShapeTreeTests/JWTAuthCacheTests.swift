import Foundation
import JWTKit
import Testing

@testable import ShapeTree

@Suite
struct JWTAuthCacheTests {

  @Test func cacheHitWhenFileStampUnchanged() async throws {
    let fixture = try await JWTTestSupport.makeFixture(label: "device-a")
    let cache = JWTAuthCache()

    _ = try await cache.entry(for: fixture.kid, store: fixture.store)
    #expect(await cache.count == 1)

    let (_, stored) = try await cache.entry(for: fixture.kid, store: fixture.store)
    #expect(await cache.count == 1)
    #expect(stored.label == "device-a")
  }

  @Test func missingFileEvictsCacheEntry() async throws {
    let fixture = try await JWTTestSupport.makeFixture()
    let cache = JWTAuthCache()

    _ = try await cache.entry(for: fixture.kid, store: fixture.store)
    #expect(await cache.count == 1)

    let file = fixture.directory.appendingPathComponent("\(fixture.kid).jwk", isDirectory: false)
    try FileManager.default.removeItem(at: file)

    do {
      _ = try await cache.entry(for: fixture.kid, store: fixture.store)
      Issue.record("Expected missing authorized key")
    } catch AuthorizedKeysStore.LookupError.missing {
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
    #expect(await cache.count == 0)
  }

  @Test func modifiedFileReloadsVerifier() async throws {
    let fixture = try await JWTTestSupport.makeFixture(label: "before")
    let cache = JWTAuthCache()

    _ = try await cache.entry(for: fixture.kid, store: fixture.store)

    let file = fixture.directory.appendingPathComponent("\(fixture.kid).jwk", isDirectory: false)
    var jwk = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    jwk["label"] = "after"
    try JSONSerialization.data(withJSONObject: jwk, options: [.sortedKeys]).write(to: file)

    let (_, stored) = try await cache.entry(for: fixture.kid, store: fixture.store)
    #expect(stored.label == "after")
    #expect(await cache.count == 1)
  }

  @Test func malformedReloadEvictsCacheAndCanRecover() async throws {
    let fixture = try await JWTTestSupport.makeFixture(label: "good")
    let cache = JWTAuthCache()
    let file = fixture.directory.appendingPathComponent("\(fixture.kid).jwk", isDirectory: false)
    let validData = try Data(contentsOf: file)

    _ = try await cache.entry(for: fixture.kid, store: fixture.store)
    #expect(await cache.count == 1)

    try Data("{ not-json".utf8).write(to: file)

    do {
      _ = try await cache.entry(for: fixture.kid, store: fixture.store)
      Issue.record("Expected malformed authorized key")
    } catch AuthorizedKeysStore.LookupError.malformed {
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
    #expect(await cache.count == 0)

    do {
      _ = try await cache.entry(for: fixture.kid, store: fixture.store)
      Issue.record("Expected malformed authorized key on retry")
    } catch AuthorizedKeysStore.LookupError.malformed {
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
    #expect(await cache.count == 0)

    try validData.write(to: file)
    let (_, stored) = try await cache.entry(for: fixture.kid, store: fixture.store)
    #expect(stored.label == "good")
    #expect(await cache.count == 1)
  }

  @Test func malformedKeyNeverEntersCache() async throws {
    let fixture = try await JWTTestSupport.makeFixture()
    let file = fixture.directory.appendingPathComponent("\(fixture.kid).jwk", isDirectory: false)
    try Data("[]".utf8).write(to: file)

    let cache = JWTAuthCache()
    do {
      _ = try await cache.entry(for: fixture.kid, store: fixture.store)
      Issue.record("Expected malformed authorized key")
    } catch AuthorizedKeysStore.LookupError.malformed {
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
    #expect(await cache.count == 0)
  }
}
