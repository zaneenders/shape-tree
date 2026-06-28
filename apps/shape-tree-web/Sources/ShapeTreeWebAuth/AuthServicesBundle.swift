import Hummingbird
import Logging
import PostgresNIO

package struct AuthServicesBundle: Sendable {
  package let services: AuthServices
  let persistDriver: PostgresPersistDriver
  private let postgresClient: PostgresClient

  init(
    services: AuthServices,
    persistDriver: PostgresPersistDriver,
    postgresClient: PostgresClient
  ) {
    self.services = services
    self.persistDriver = persistDriver
    self.postgresClient = postgresClient
  }

  package func addServices<R: HTTPResponder>(
    to app: inout Application<R>
  ) where R.Context: InitializableFromSource<ApplicationRequestContextSource> {
    app.addServices(postgresClient)
  }

  package func runStartupTasks(logger: Logger) async throws {
    try await Migrations.run(client: postgresClient, logger: logger)
    try await services.database.deleteExpiredLoginTokens(logger: logger)
    try await persistDriver.tidyExpired()
  }
}
