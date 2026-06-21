import Foundation

package actor LoginRateLimiter: Sendable {

  private var attempts: [String: [Date]] = [:]
  private let window: Duration
  private let maxAttempts: Int

  package init(window: Duration = .seconds(60), maxAttempts: Int = 3) {
    self.window = window
    self.maxAttempts = maxAttempts
  }

  func allow(ip: String) -> Bool {
    let now = Date.now
    let cutoff = now.addingTimeInterval(-windowSeconds)
    let recent = (attempts[ip] ?? []).filter { $0 > cutoff }
    guard recent.count < maxAttempts else {
      attempts[ip] = recent
      return false
    }
    attempts[ip] = recent + [now]
    return true
  }

  private var windowSeconds: Double {
    let (seconds, attoseconds) = window.components
    return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
  }
}
