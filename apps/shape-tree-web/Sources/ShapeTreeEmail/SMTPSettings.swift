import Configuration
import Foundation
import Logging

private let smtpSettingsLogger = Logger(label: "ShapeTreeEmail.SMTPSettings")

public struct SMTPSettings: Sendable {
  public let connection: SMTPConnectionSettings
  public let fromAddress: String

  public static func load(from config: ConfigReader) -> SMTPSettings? {
    guard
      let host = nonEmpty(config.string(forKey: "SMTP_HOST", isSecret: false)),
      let port = config.int(forKey: "SMTP_PORT"),
      (1...65535).contains(port),
      let fromAddress = nonEmpty(config.string(forKey: "SMTP_FROM", isSecret: false))
    else {
      return nil
    }

    let tlsMode = tlsMode(from: config.string(forKey: "SMTP_TLS", isSecret: false))
    let username = config.string(forKey: "SMTP_USERNAME", isSecret: false) ?? ""
    let password = config.string(forKey: "SMTP_PASSWORD", isSecret: true) ?? ""

    if tlsMode != .plain, username.isEmpty || password.isEmpty {
      return nil
    }

    smtpSettingsLogger.info(
      "SMTP settings loaded",
      metadata: [
        "host": "\(host)",
        "port": "\(port)",
        "username": "\(username)",
        "passwordLength": "\(password.count)",
        "tlsMode": "\(tlsMode)",
        "fromAddress": "\(fromAddress)",
      ])

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

  static func integrationTestEnabled(in config: ConfigReader) -> Bool {
    guard config.string(forKey: "SMTP_INTEGRATION_TEST", isSecret: false)?.lowercased() == "true"
    else {
      return false
    }
    guard load(from: config) != nil, IMAPSettings.load(from: config) != nil else {
      return false
    }
    let recipient =
      config.string(forKey: "SMTP_TEST_TO", isSecret: false)
      ?? config.string(forKey: "SMTP_FROM", isSecret: false)
    return !(recipient ?? "").isEmpty
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func tlsMode(from raw: String?) -> SMTPTLSMode {
    switch raw?.lowercased() {
    case "plain", "none", "disable":
      return .plain
    case "implicit", "ssl", "tls":
      return .implicitTLS
    default:
      return .startTLS
    }
  }

  public func makeEmail(to recipient: String, subject: String, body: String) -> OutgoingEmail {
    OutgoingEmail(
      senderEmail: fromAddress,
      recipientEmail: recipient,
      subject: subject,
      body: body
    )
  }

  public func makeTestEmail(to recipient: String, subject: String, body: String) -> OutgoingEmail {
    makeEmail(to: recipient, subject: subject, body: body)
  }
}
