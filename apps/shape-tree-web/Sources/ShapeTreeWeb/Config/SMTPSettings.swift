import Configuration
import Foundation

struct SMTPSettings: Sendable {
  let connection: SMTPConnectionSettings
  let fromAddress: String

  static func load(from config: ConfigReader) -> SMTPSettings? {
    load(from: mergedEnvironment(config: config))
  }

  static func loadFromEnvironment() -> SMTPSettings? {
    load(from: mergedEnvironment())
  }

  static func integrationTestEnabled() -> Bool {
    let values = mergedEnvironment()
    guard values["SMTP_INTEGRATION_TEST"]?.lowercased() == "true" else {
      return false
    }
    guard load(from: values) != nil, IMAPSettings.load(from: values) != nil else {
      return false
    }
    let recipient = values["SMTP_TEST_TO"] ?? values["SMTP_FROM"]
    return !(recipient ?? "").isEmpty
  }

  static func mergedEnvironment(config: ConfigReader? = nil) -> [String: String] {
    var values = loadDotEnvFile()
    if let config {
      for key in ["SMTP_HOST", "SMTP_PORT", "SMTP_USERNAME", "SMTP_PASSWORD", "SMTP_FROM", "SMTP_TLS"] {
        if let value = config.string(forKey: ConfigKey(key), isSecret: key == "SMTP_PASSWORD") {
          values[key] = value
        }
      }
      for key in [
        "IMAP_HOST", "IMAP_PORT", "IMAP_USERNAME", "IMAP_PASSWORD", "IMAP_MAILBOX", "SMTP_INTEGRATION_TEST",
        "SMTP_TEST_TO", "IMAP_FETCH_LIMIT", "IMAP_ROUND_TRIP_TIMEOUT_SECONDS", "IMAP_ROUND_TRIP_POLL_SECONDS",
      ] {
        if let value = config.string(forKey: ConfigKey(key), isSecret: key == "IMAP_PASSWORD") {
          values[key] = value
        }
      }
    }
    for (key, value) in ProcessInfo.processInfo.environment where !value.isEmpty {
      values[key] = value
    }
    return values
  }

  private static func load(from values: [String: String]) -> SMTPSettings? {
    guard
      let host = values["SMTP_HOST"],
      let portString = values["SMTP_PORT"],
      let port = Int(portString),
      let username = values["SMTP_USERNAME"],
      let password = values["SMTP_PASSWORD"],
      let fromAddress = values["SMTP_FROM"],
      !host.isEmpty,
      !username.isEmpty,
      !password.isEmpty,
      !fromAddress.isEmpty,
      port >= 1,
      port <= 65535
    else {
      return nil
    }

    let tlsMode: SMTPTLSMode
    switch values["SMTP_TLS"]?.lowercased() {
    case "implicit", "ssl", "tls":
      tlsMode = .implicitTLS
    default:
      tlsMode = .startTLS
    }

    return SMTPSettings(
      connection: SMTPConnectionSettings(
        host: host,
        port: port,
        username: username,
        password: password,
        tlsMode: tlsMode
      ),
      fromAddress: fromAddress
    )
  }

  private static func loadDotEnvFile() -> [String: String] {
    let searchPaths = [
      ".env",
      "../.env",
      "../../.env",
    ]

    for path in searchPaths {
      guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
        continue
      }
      return parseDotEnv(contents)
    }
    return [:]
  }

  private static func parseDotEnv(_ contents: String) -> [String: String] {
    var values: [String: String] = [:]
    for line in contents.split(whereSeparator: \.isNewline) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty || trimmed.hasPrefix("#") {
        continue
      }
      guard let separator = trimmed.firstIndex(of: "=") else {
        continue
      }
      let key = String(trimmed[..<separator])
      var value = String(trimmed[trimmed.index(after: separator)...])
      if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
        value = String(value.dropFirst().dropLast())
      }
      if !key.isEmpty, !value.isEmpty {
        values[key] = value
      }
    }
    return values
  }

  func makeEmail(to recipient: String, subject: String, body: String) -> OutgoingEmail {
    OutgoingEmail(
      senderEmail: fromAddress,
      recipientEmail: recipient,
      subject: subject,
      body: body
    )
  }

  func makeTestEmail(to recipient: String, subject: String, body: String) -> OutgoingEmail {
    makeEmail(to: recipient, subject: subject, body: body)
  }
}
