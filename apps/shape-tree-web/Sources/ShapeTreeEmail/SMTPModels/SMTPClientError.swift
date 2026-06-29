import Foundation

public enum SMTPClientError: Error, CustomStringConvertible, Sendable {
  case serverRejected(String, host: String, port: Int)
  case tlsUnavailable(Error)

  public var description: String {
    switch self {
    case .serverRejected(let message, let host, let port):
      return "SMTP server \(host):\(port) rejected the request: \(message)"
    case .tlsUnavailable(let error):
      return "SMTP TLS unavailable: \(error)"
    }
  }
}
