import Configuration
import Foundation

struct IMAPSettings: Sendable {
  let connection: IMAPConnectionSettings

  static let iCloudDefaults = IMAPSettings(
    connection: IMAPConnectionSettings(
      host: "imap.mail.me.com",
      port: 993,
      username: "",
      password: ""
    )
  )

  static func load(from config: ConfigReader) -> IMAPSettings? {
    let username =
      nonEmpty(config.string(forKey: "IMAP_USERNAME", isSecret: false))
      ?? nonEmpty(config.string(forKey: "SMTP_USERNAME", isSecret: false))
    let password =
      config.string(forKey: "IMAP_PASSWORD", isSecret: true)
      ?? config.string(forKey: "SMTP_PASSWORD", isSecret: true)

    guard let username, let password, !password.isEmpty else {
      return nil
    }

    let host = nonEmpty(config.string(forKey: "IMAP_HOST", isSecret: false)) ?? "imap.mail.me.com"
    let port = config.int(forKey: "IMAP_PORT") ?? 993
    guard (1...65535).contains(port) else {
      return nil
    }

    return IMAPSettings(
      connection: IMAPConnectionSettings(
        host: host,
        port: port,
        username: username,
        password: password
      )
    )
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
