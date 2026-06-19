import Foundation

/// Recent `(kid, jti)` pairs until each token's `exp`; rejects replay inside TTL.
/// Process-local only — use a shared store if you run multiple server replicas.
public actor JWTReplayCache {
  public enum Decision: Sendable {
    case fresh
    case replay
  }

  public enum AdmissionError: Error, Sendable, CustomStringConvertible {
    case capacityExceeded

    public var description: String {
      switch self {
      case .capacityExceeded:
        return "JWT replay cache is at capacity; refusing to admit new tokens"
      }
    }
  }

  public static let defaultCapacity = 10_000

  public static let defaultPurgeInterval: TimeInterval = 60

  private struct Entry: Sendable {
    let exp: Date
  }

  private let capacity: Int
  private let purgeInterval: TimeInterval
  private var entries: [String: Entry] = [:]
  private var lastPurge: Date = .distantPast

  public init(
    capacity: Int = JWTReplayCache.defaultCapacity,
    purgeInterval: TimeInterval = JWTReplayCache.defaultPurgeInterval
  ) {
    self.capacity = max(1, capacity)
    self.purgeInterval = purgeInterval
  }

  /// First sight → `.fresh` and record; duplicate before `exp` → `.replay`.
  /// Throws `capacityExceeded` when full after purging expired entries (middleware → 503).
  public func admit(
    kid: String,
    jti: String,
    exp: Date,
    now: Date = Date()
  ) throws -> Decision {
    purgeIfDue(now: now)

    let key = Self.cacheKey(kid: kid, jti: jti)
    if let existing = entries[key], existing.exp > now {
      return .replay
    }

    if entries.count >= capacity {
      purgeExpired(now: now)
      if entries.count >= capacity {
        throw AdmissionError.capacityExceeded
      }
    }

    entries[key] = Entry(exp: exp)
    return .fresh
  }

  public var entryCount: Int { entries.count }

  private static func cacheKey(kid: String, jti: String) -> String {
    "\(kid):\(jti)"
  }

  private func purgeIfDue(now: Date) {
    guard now.timeIntervalSince(lastPurge) >= purgeInterval else { return }
    purgeExpired(now: now)
    lastPurge = now
  }

  private func purgeExpired(now: Date) {
    entries = entries.filter { $0.value.exp > now }
  }
}
