import Foundation
import JWTKit

/// Caches ``JWTKeyCollection`` and ``AuthorizedKeysStore/StoredKey`` per `kid`.
/// On cache hit, re-stat the JWK (`contentModificationDate` + size); reload only when
/// the file changed or disappeared, so `cp` / `rm` in `authorized_keys/` take effect
/// on the next request without a server restart.
public actor JWTAuthCache {

  private struct Entry: Sendable {
    let keyCollection: JWTKeyCollection
    let storedKey: AuthorizedKeysStore.StoredKey
    let fileStamp: AuthorizedKeysStore.FileStamp
  }

  private var entries: [String: Entry] = [:]

  public init() {}

  /// Returns a ready-to-verify ``JWTKeyCollection`` and the stored-key metadata for `kid`.
  /// On cache hit, re-stat the JWK; reload only when the file changed or disappeared.
  func entry(
    for kid: String,
    store: AuthorizedKeysStore
  ) async throws -> (JWTKeyCollection, AuthorizedKeysStore.StoredKey) {
    if let cached = entries[kid] {
      do {
        let stamp = try store.fileStamp(kid: kid)
        if stamp == cached.fileStamp {
          return (cached.keyCollection, cached.storedKey)
        }
      } catch {
        entries.removeValue(forKey: kid)
        throw error
      }
      entries.removeValue(forKey: kid)
    }

    let stamp = try store.fileStamp(kid: kid)
    let stored = try store.load(kid: kid)
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: stored.publicKey)
    let entry = Entry(keyCollection: keys, storedKey: stored, fileStamp: stamp)
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
