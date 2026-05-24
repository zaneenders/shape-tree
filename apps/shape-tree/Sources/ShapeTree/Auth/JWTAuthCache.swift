import Foundation
import JWTKit
import Logging

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
  private let log: Logger

  public init(log: Logger = Logger(label: "shape-tree.auth.cache")) {
    self.log = log
  }

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
          log.debug("event=auth.cache.hit kid=\(kid)")
          return (cached.keyCollection, cached.storedKey)
        }
        log.debug("event=auth.cache.stale kid=\(kid)")
      } catch {
        entries.removeValue(forKey: kid)
        log.info("event=auth.cache.evict kid=\(kid) reason=unavailable error=\(error)")
        throw error
      }
      entries.removeValue(forKey: kid)
    }

    do {
      let (stored, stamp) = try store.load(kid: kid)
      let keys = JWTKeyCollection()
      await keys.add(ecdsa: stored.publicKey)
      entries[kid] = Entry(keyCollection: keys, storedKey: stored, fileStamp: stamp)
      log.debug("event=auth.cache.loaded kid=\(kid) entries=\(entries.count)")
      return (keys, stored)
    } catch {
      entries.removeValue(forKey: kid)
      log.warning("event=auth.cache.load_failed kid=\(kid) error=\(error)")
      throw error
    }
  }

  /// Drop a cached entry so the next lookup re-reads from disk (use after key rotation).
  func invalidate(kid: String) {
    entries.removeValue(forKey: kid)
  }

  /// Number of currently cached kids.
  public var count: Int { entries.count }
}
