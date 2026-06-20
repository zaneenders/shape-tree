import Foundation

actor LoginRateLimiter {
  private var emailHits: [String: [Date]] = [:]
  private var ipHits: [String: [Date]] = [:]

  private let emailLimit = 5
  private let ipLimit = 20
  private let window: TimeInterval = 3600

  func allow(email: String, ip: String) -> Bool {
    let now = Date()
    prune(&emailHits[email, default: []], now: now)
    prune(&ipHits[ip, default: []], now: now)
    guard emailHits[email, default: []].count < emailLimit,
      ipHits[ip, default: []].count < ipLimit
    else {
      return false
    }
    emailHits[email, default: []].append(now)
    ipHits[ip, default: []].append(now)
    return true
  }

  private func prune(_ hits: inout [Date], now: Date) {
    hits.removeAll { now.timeIntervalSince($0) > window }
  }
}
