import Foundation
import Hummingbird
import Logging
import PostgresNIO

final class PostgresPersistDriver: PersistDriver, Sendable {
  let client: PostgresClient
  let logger: Logger

  init(client: PostgresClient, logger: Logger) {
    self.client = client
    self.logger = logger
  }

  func create(key: String, value: some Encodable & Sendable, expires: Duration?) async throws {
    let payload = try encode(value)
    let expiresAt = expirationDate(for: expires)
    do {
      try await PersistQueries.persistCreate(
        client, id: key, data: payload, expires: expiresAt, logger: logger)
    } catch {
      if isUniqueViolation(error) {
        throw PersistError.duplicate
      }
      throw error
    }
  }

  func set(key: String, value: some Encodable & Sendable, expires: Duration?) async throws {
    let payload = try encode(value)
    let expiresAt = expirationDate(for: expires)
    try await PersistQueries.persistSet(
      client, id: key, data: payload, expires: expiresAt, logger: logger)
  }

  func get<Object: Decodable & Sendable>(
    key: String,
    as object: Object.Type
  ) async throws -> Object? {
    guard let row = try await PersistQueries.persistGet(client, id: key, logger: logger) else {
      return nil
    }
    do {
      return try decode(row.data, as: Object.self)
    } catch {
      throw PersistError.invalidConversion
    }
  }

  func getWithTTL<Object: Decodable & Sendable>(
    key: String,
    as object: Object.Type
  ) async throws -> (object: Object, ttl: Duration?)? {
    guard let row = try await PersistQueries.persistGet(client, id: key, logger: logger) else {
      return nil
    }
    do {
      let value = try decode(row.data, as: Object.self)
      if row.expires == Date.distantFuture {
        return (value, nil)
      }
      let ttl = Duration.seconds(max(0, row.expires.timeIntervalSinceNow))
      return (value, ttl)
    } catch {
      throw PersistError.invalidConversion
    }
  }

  func remove(key: String) async throws {
    try await PersistQueries.persistRemove(client, id: key, logger: logger)
  }

  func tidyExpired() async throws {
    try await PersistQueries.persistDeleteExpired(client, logger: logger)
  }

  private func encode(_ value: some Encodable) throws -> String {
    let data = try JSONEncoder().encode(AnyEncodable(value))
    guard let json = String(data: data, encoding: .utf8) else {
      throw PersistError.invalidConversion
    }
    return json
  }

  private func decode<Object: Decodable>(_ json: String, as type: Object.Type) throws -> Object {
    let data = Data(json.utf8)
    return try JSONDecoder().decode(Object.self, from: data)
  }

  private func expirationDate(for expires: Duration?) -> Date {
    expires.map { Date.now + Double($0.components.seconds) } ?? .distantFuture
  }

  private func isUniqueViolation(_ error: Error) -> Bool {
    guard let error = error as? PSQLError else { return false }
    if case .server = error.code {
      return error.serverInfo?[.sqlState] == "23505"
    }
    return false
  }
}

private struct AnyEncodable: Encodable {
  let value: any Encodable

  init(_ value: some Encodable) {
    self.value = value
  }

  func encode(to encoder: any Encoder) throws {
    try value.encode(to: encoder)
  }
}
