import Foundation
import Hummingbird
import Logging
import PostgresNIO

protocol AuthDatabase: Sendable {
  func user(email: String, logger: Logger) async throws -> User?
  func user(id: UUID, logger: Logger) async throws -> User?
  func createUser(email: String, logger: Logger) async throws -> User
  func createLoginToken(userID: UUID, tokenHash: String, expiresAt: Date, logger: Logger) async throws
  func consumeLoginToken(hash: String, logger: Logger) async throws -> UUID?
  func deleteExpiredLoginTokens(logger: Logger) async throws
}

struct PostgresAuthDatabase: AuthDatabase {
  let client: PostgresClient

  func user(email: String, logger: Logger) async throws -> User? {
    guard
      let row = try await UsersQueries.getUserByEmail(
        client, email: email, logger: logger)
    else {
      return nil
    }
    return User(id: row.id, email: row.email, createdAt: row.createdAt)
  }

  func user(id: UUID, logger: Logger) async throws -> User? {
    guard let row = try await UsersQueries.getUserByID(client, id: id, logger: logger) else {
      return nil
    }
    return User(id: row.id, email: row.email, createdAt: row.createdAt)
  }

  func createUser(email: String, logger: Logger) async throws -> User {
    let id = UUID()
    try await UsersQueries.createUser(client, id: id, email: email, logger: logger)
    guard let user = try await user(email: email, logger: logger) else {
      throw CreateUserError.insertDidNotPersist(email)
    }
    return user
  }

  enum CreateUserError: Error, CustomStringConvertible {
    case insertDidNotPersist(String)

    var description: String {
      switch self {
      case .insertDidNotPersist(let email):
        return "Created user row for \(email) but could not read it back"
      }
    }
  }

  func createLoginToken(
    userID: UUID,
    tokenHash: String,
    expiresAt: Date,
    logger: Logger
  ) async throws {
    try await LoginTokensQueries.createLoginToken(
      client,
      id: UUID(),
      userId: userID,
      tokenHash: tokenHash,
      expiresAt: expiresAt,
      logger: logger
    )
  }

  func consumeLoginToken(hash: String, logger: Logger) async throws -> UUID? {
    try await LoginTokensQueries.consumeLoginToken(
      client, tokenHash: hash, logger: logger)
  }

  func deleteExpiredLoginTokens(logger: Logger) async throws {
    try await LoginTokensQueries.deleteExpiredLoginTokens(client, logger: logger)
  }
}
