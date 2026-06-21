import Configuration
import Foundation
import Logging
import PostgresNIO

package enum AuthCLI {
  package static func addUser(email rawEmail: String, logger: Logger) async throws {
    guard let email = AuthEmail.validatedEmail(rawEmail) else {
      logger.error("Invalid email: \(rawEmail)")
      return
    }

    let secretKeys = SecretsSpecifier<String, String>.specific([
      "PGPASSWORD", "SMTP_PASSWORD",
    ])
    let config = ConfigReader(providers: [
      EnvironmentVariablesProvider(secretsSpecifier: secretKeys),
      try await EnvironmentVariablesProvider(
        environmentFilePath: ".env",
        allowMissing: true,
        secretsSpecifier: secretKeys
      ),
    ])

    let postgresSettings = try PostgresSettings.load(from: config)
    let client = PostgresClient(configuration: postgresSettings.configuration)
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { await client.run() }
      try await Migrations.run(client: client, logger: logger)
      let database = PostgresAuthDatabase(client: client)
      if let existing = try await database.user(email: email, logger: logger) {
        logger.notice("User already exists: \(existing.email) (\(existing.id))")
      } else {
        let user = try await database.createUser(email: email, logger: logger)
        logger.notice("Added user: \(user.email) (\(user.id))")
      }
      group.cancelAll()
    }
  }
}
