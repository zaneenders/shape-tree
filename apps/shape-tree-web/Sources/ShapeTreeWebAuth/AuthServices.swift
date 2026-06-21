import Configuration
import Foundation
import Hummingbird
import Logging
import PostgresNIO
import ShapeTreeWebEmail

package struct AuthServices: Sendable {
  let database: any AuthDatabase
  let persist: any PersistDriver
  let settings: AuthSettings
  let smtp: SMTPSettings
  let siteURL: String
  let secureCookies: Bool

  package static func bootstrap(
    from config: ConfigReader,
    siteURL: String,
    logger: Logger
  ) async throws -> AuthServicesBundle {
    do {
      let postgresSettings = try PostgresSettings.load(from: config)
      let client = PostgresClient(configuration: postgresSettings.configuration)
      let authSettings = AuthSettings.load(from: config)
      let smtp = SMTPSettings.load(from: config)
      guard let smtp else {
        throw AuthSetupError(
          "SMTP is required when Postgres auth is configured. Set SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, and SMTP_FROM in .env or the environment."
        )
      }
      let secureCookies = URL(string: siteURL)?.scheme == "https"

      let persist = PostgresPersistDriver(client: client, logger: logger)
      let database = PostgresAuthDatabase(client: client)
      return AuthServicesBundle(
        services: AuthServices(
          database: database,
          persist: persist,
          settings: authSettings,
          smtp: smtp,
          siteURL: siteURL,
          secureCookies: secureCookies
        ),
        persistDriver: persist,
        postgresClient: client
      )
    } catch let error as AuthSetupError {
      throw error
    } catch {
      throw AuthSetupError("\(error)")
    }
  }
}

struct AuthSetupError: Error, CustomStringConvertible {
  let message: String
  init(_ message: String) { self.message = message }
  var description: String { message }
}
