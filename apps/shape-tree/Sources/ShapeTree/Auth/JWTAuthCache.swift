import Foundation
import JWTKit

/// Caches ``JWTKeyCollection`` and ``AuthorizedKeysStore/StoredKey`` per `kid` so the
/// middleware avoids reading the JWK file from disk and rebuilding the BoringSSL-backed
/// verifier on every request.
public actor JWTAuthCache {

  private struct Entry: Sendable {
    let keyCollection: JWTKeyCollection
    let storedKey: AuthorizedKeysStore.StoredKey
  }

  private var entries: [String: Entry] = [:]

  public init() {}

  /// Returns a ready-to-verify ``JWTKeyCollection`` and the stored-key metadata for `kid`.
  /// Loads from disk only on first sight; subsequent calls return the cached value.
  func entry(
    for kid: String,
    store: AuthorizedKeysStore
  ) async throws -> (JWTKeyCollection, AuthorizedKeysStore.StoredKey) {
    if let cached = entries[kid] {
      return (cached.keyCollection, cached.storedKey)
    }
    let stored = try store.load(kid: kid)
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: stored.publicKey)
    let entry = Entry(keyCollection: keys, storedKey: stored)
    entries[kid] = entry
    return (keys, stored)
  }

  /// Drop a cached entry so the next lookup re-reads from disk (use after key rotation).
  func invalidate(kid: String) {
    entries.removeValue(forKey: kid)
  }

  /// Number of currently cached kids.
  public var count: Int { entries.count }
}
