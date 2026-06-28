import Configuration
import Foundation
import Hummingbird
import Logging
import PostgresNIO
import ShapeTreeEmail

package struct AuthServices: Sendable {
  let database: any AuthDatabase
  let persist: any PersistDriver
  let settings: AuthSettings
  let config: ConfigReader
  let siteURL: String
  let secureCookies: Bool

  /// Boots when Postgres is configured. SMTP is loaded when a login email is sent.
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
