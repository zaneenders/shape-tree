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
    var values = SMTPSettings.mergedEnvironment()
    if let host = config.string(forKey: "IMAP_HOST", isSecret: false), !host.isEmpty {
      values["IMAP_HOST"] = host
    }
    if let port = config.int(forKey: "IMAP_PORT") {
      values["IMAP_PORT"] = String(port)
    }
    if let username = config.string(forKey: "IMAP_USERNAME", isSecret: false), !username.isEmpty {
      values["IMAP_USERNAME"] = username
    }
    if let password = config.string(forKey: "IMAP_PASSWORD", isSecret: true), !password.isEmpty {
      values["IMAP_PASSWORD"] = password
    }
    if let username = config.string(forKey: "SMTP_USERNAME", isSecret: false), !username.isEmpty {
      values["SMTP_USERNAME"] = username
    }
    if let password = config.string(forKey: "SMTP_PASSWORD", isSecret: true), !password.isEmpty {
      values["SMTP_PASSWORD"] = password
    }
    return load(from: values)
  }

  static func loadFromEnvironment() -> IMAPSettings? {
    load(from: SMTPSettings.mergedEnvironment())
  }

  static func integrationTestEnabled() -> Bool {
    SMTPSettings.integrationTestEnabled()
  }

  static func load(from values: [String: String]) -> IMAPSettings? {
    let username = values["IMAP_USERNAME"] ?? values["SMTP_USERNAME"]
    let password = values["IMAP_PASSWORD"] ?? values["SMTP_PASSWORD"]

    guard
      let username,
      let password,
      !username.isEmpty,
      !password.isEmpty
    else {
      return nil
    }

    let host = values["IMAP_HOST"] ?? "imap.mail.me.com"
    let port = Int(values["IMAP_PORT"] ?? "993") ?? 993
    guard port >= 1, port <= 65535 else {
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
}
