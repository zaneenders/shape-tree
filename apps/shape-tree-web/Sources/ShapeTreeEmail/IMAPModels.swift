import Foundation

struct IMAPConnectionSettings: Sendable {
  var host: String
  var port: Int
  var username: String
  var password: String
}

struct IncomingEmail: Sendable, Equatable {
  var uid: UInt32?
  var sequenceNumber: UInt32?
  var from: String
  var subject: String
  var date: String
  var body: String?

  init(
    uid: UInt32? = nil,
    sequenceNumber: UInt32? = nil,
    from: String,
    subject: String,
    date: String,
    body: String? = nil
  ) {
    self.uid = uid
    self.sequenceNumber = sequenceNumber
    self.from = from
    self.subject = subject
    self.date = date
    self.body = body
  }
}

enum IMAPClientError: Error, CustomStringConvertible, Sendable {
  case serverRejected(String, host: String, port: Int)
  case unexpectedResponse(String)
  case protocolError(String)

  var description: String {
    switch self {
    case .serverRejected(let message, let host, let port):
      return "IMAP server \(host):\(port) rejected the request: \(message)"
    case .unexpectedResponse(let message):
      return "Unexpected IMAP response: \(message)"
    case .protocolError(let message):
      return "IMAP protocol error: \(message)"
    }
  }
}
