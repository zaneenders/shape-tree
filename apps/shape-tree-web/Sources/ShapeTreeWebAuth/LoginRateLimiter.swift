import Foundation

package actor LoginRateLimiter: Sendable {
  private struct Key: Hashable {
    let email: String
    let ip: String
  }

  private var attempts: [Key: [Date]] = [:]
  private let window: Duration
  private let maxAttempts: Int

  package init(window: Duration = .seconds(60), maxAttempts: Int = 3) {
    self.window = window
    self.maxAttempts = maxAttempts
  }

  func allow(email: String, ip: String) -> Bool {
    let key = Key(email: email, ip: ip)
    let now = Date.now
    let cutoff = now.addingTimeInterval(-windowSeconds)
    let recent = (attempts[key] ?? []).filter { $0 > cutoff }
    guard recent.count < maxAttempts else {
      attempts[key] = recent
      return false
    }
    attempts[key] = recent + [now]
    return true
  }

  private var windowSeconds: Double {
    let (seconds, attoseconds) = window.components
    return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
  }
}
