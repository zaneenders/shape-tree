import Configuration
import Foundation
import Logging

private let imapSettingsLogger = Logger(label: "ShapeTreeEmail.IMAPSettings")

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
    guard let username = nonEmpty(config.string(forKey: "IMAP_USERNAME", isSecret: false)) else {
      imapSettingsLogger.info("IMAP_USERNAME not set — IMAP disabled")
      return nil
    }
    guard let password = config.string(forKey: "IMAP_PASSWORD", isSecret: true), !password.isEmpty else {
      imapSettingsLogger.info("IMAP_PASSWORD not set — IMAP disabled")
      return nil
    }

    let host = nonEmpty(config.string(forKey: "IMAP_HOST", isSecret: false)) ?? "imap.mail.me.com"
    let port = config.int(forKey: "IMAP_PORT") ?? 993
    guard (1...65535).contains(port) else {
      return nil
    }

    imapSettingsLogger.info(
      "IMAP settings loaded",
      metadata: [
        "host": "\(host)",
        "port": "\(port)",
        "username": "\(username)",
        "passwordLength": "\(password.count)",
      ])

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
