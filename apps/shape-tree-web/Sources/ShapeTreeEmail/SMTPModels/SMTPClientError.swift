import Foundation

public enum SMTPClientError: Error, CustomStringConvertible, Sendable {
  case serverRejected(String)
  case tlsUnavailable(Error)

  public var description: String {
    switch self {
    case .serverRejected(let message):
      return "SMTP server rejected the request: \(message)"
    case .tlsUnavailable(let error):
      return "SMTP TLS unavailable: \(error)"
    }
  }
}
