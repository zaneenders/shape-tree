import Configuration
import Foundation
import Hummingbird
import Logging
import PostgresNIO
import ShapeTreeEmail

package enum AuthBootError: Error, CustomStringConvertible {
  case smtpTLSUnavailable(Error)
  case unableToLoadSettings

  package var description: String {
    switch self {
    case .smtpTLSUnavailable(let error):
      return """
        SMTP TLS unavailable at boot: \(error). \
        If running in a scratch/minimal image, install CA certificates \
        (e.g. /etc/ssl/certs/ca-certificates.crt).
        """
    case .unableToLoadSettings:
      return "Unable to load .env settings for AuthServices"
    }
  }
}

package struct AuthServices: Sendable {
  let database: any AuthDatabase
  let persist: any PersistDriver
  let settings: AuthSettings
  let config: ConfigReader
  let siteURL: String
  let secureCookies: Bool

  /// Boots when Postgres is configured. SMTP settings are loaded and validated eagerly at boot.
  package static func bootstrapIfConfigured(
    from config: ConfigReader,
    siteURL: String,
    logger: Logger
  ) async throws -> AuthServicesBundle? {
    guard let postgresSettings = try? PostgresSettings.load(from: config) else {
      return nil
    }

    let client = PostgresClient(configuration: postgresSettings.configuration)
    let authSettings = AuthSettings.load(from: config)
    let secureCookies = URL(string: siteURL)?.scheme == "https"

    guard let smtp = SMTPSettings.load(from: config) else {
      throw AuthBootError.unableToLoadSettings
    }
    try smtp.connection.validateTLSConfigured()

    let persist = PostgresPersistDriver(client: client, logger: logger)
    let database = PostgresAuthDatabase(client: client)
    return AuthServicesBundle(
      services: AuthServices(
        database: database,
        persist: persist,
        settings: authSettings,
        config: config,
        siteURL: siteURL,
        secureCookies: secureCookies
      ),
      persistDriver: persist,
      postgresClient: client
    )
  }
}
