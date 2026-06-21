import Foundation

enum SMTPRequest: Sendable {
  case sayHello(serverName: String)
  case startTLS
  case beginAuthentication
  case authUser(String)
  case authPassword(String)
  case mailFrom(String)
  case recipient(String)
  case data
  case transferData(OutgoingEmail)
  case quit
}

enum SMTPResponse: Sendable {
  case ok(Int, String)
  case error(String)
}

public enum SMTPTLSMode: Sendable {
  /// STARTTLS on a plain connection (iCloud default on port 587).
  case startTLS
  /// TLS from the first byte (port 465).
  case implicitTLS
}

public struct SMTPConnectionSettings: Sendable {
  public var host: String
  public var port: Int
  public var username: String
  public var password: String
  public var tlsMode: SMTPTLSMode

  public init(
    host: String,
    port: Int,
    username: String,
    password: String,
    tlsMode: SMTPTLSMode = .startTLS
  ) {
    self.host = host
    self.port = port
    self.username = username
    self.password = password
    self.tlsMode = tlsMode
  }
}

public struct OutgoingEmail: Sendable {
  public var senderName: String?
  public var senderEmail: String
  public var recipientName: String?
  public var recipientEmail: String
  public var subject: String
  public var body: String

  public init(
    senderName: String? = nil,
    senderEmail: String,
    recipientName: String? = nil,
    recipientEmail: String,
    subject: String,
    body: String
  ) {
    self.senderName = senderName
    self.senderEmail = senderEmail
    self.recipientName = recipientName
    self.recipientEmail = recipientEmail
    self.subject = subject
    self.body = body
  }
}

public enum SMTPClientError: Error, CustomStringConvertible, Sendable {
  case serverRejected(String)

  public var description: String {
    switch self {
    case .serverRejected(let message):
      return "SMTP server rejected the request: \(message)"
    }
  }
}
