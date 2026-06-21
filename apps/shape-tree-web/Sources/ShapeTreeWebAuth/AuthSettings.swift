import Configuration
import Foundation

struct AuthSettings: Sendable {
  let tokenTTLMinutes: Int
  let sessionTTLHours: Int

  init(tokenTTLMinutes: Int = 15, sessionTTLHours: Int = 24 * 14) {
    self.tokenTTLMinutes = tokenTTLMinutes
    self.sessionTTLHours = sessionTTLHours
  }

  var tokenTTL: Duration {
    .seconds(tokenTTLMinutes * 60)
  }

  var sessionTTL: Duration {
    .seconds(sessionTTLHours * 60 * 60)
  }

  static func load(from config: ConfigReader) -> AuthSettings {
    let tokenTTLMinutes = config.int(forKey: "AUTH_TOKEN_TTL_MINUTES") ?? 15
    let sessionTTLHours = config.int(forKey: "AUTH_SESSION_TTL_HOURS") ?? (24 * 14)
    return AuthSettings(tokenTTLMinutes: tokenTTLMinutes, sessionTTLHours: sessionTTLHours)
  }
}
