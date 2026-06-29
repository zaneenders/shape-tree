import NIOSSL

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

extension SMTPConnectionSettings {
  public func validateTLSConfigured() throws {
    guard self.tlsMode != .plain else { return }
    _ = try NIOSSLContext(configuration: TLSConfiguration.makeClientConfiguration())
  }
}
