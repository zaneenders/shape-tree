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
}
