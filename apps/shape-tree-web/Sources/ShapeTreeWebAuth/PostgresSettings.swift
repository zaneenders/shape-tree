import Configuration
import Foundation
import NIOSSL
import PostgresNIO

struct PostgresSettings: Sendable {
  let configuration: PostgresClient.Configuration

  static func load(from config: ConfigReader) throws -> PostgresSettings {
    try makeSettings(
      host: requiredString(config.string(forKey: "PGHOST"), envVar: "PGHOST"),
      port: requiredInt(config.int(forKey: "PGPORT"), envVar: "PGPORT"),
      username: requiredString(config.string(forKey: "PGUSER"), envVar: "PGUSER"),
      password: requiredString(
        config.string(forKey: "PGPASSWORD", isSecret: true), envVar: "PGPASSWORD"),
      database: requiredString(config.string(forKey: "PGDATABASE"), envVar: "PGDATABASE"),
      sslMode: config.string(forKey: "PGSSLMODE", isSecret: false)
    )
  }

  private static func makeSettings(
    host: String,
    port: Int,
    username: String,
    password: String,
    database: String,
    sslMode: String?
  ) throws -> PostgresSettings {
    guard port >= 1, port <= 65535 else {
      throw ConfigError.invalidPort(envVar: "PGPORT", value: port)
    }

    let tls: PostgresClient.Configuration.TLS
    switch sslMode?.lowercased() {
    case "require", "verify-full", "verify-ca":
      tls = .prefer(TLSConfiguration.makeClientConfiguration())
    default:
      tls = .disable
    }

    return PostgresSettings(
      configuration: .init(
        host: host,
        port: port,
        username: username,
        password: password,
        database: database,
        tls: tls
      )
    )
  }

  private static func requiredString(_ value: String?, envVar: String) throws -> String {
    guard let value, !value.isEmpty else {
      throw ConfigError.missingRequiredField("\(envVar) (set in .env or the environment)")
    }
    return value
  }

  private static func requiredInt(_ value: Int?, envVar: String) throws -> Int {
    guard let value else {
      throw ConfigError.missingRequiredField("\(envVar) (set in .env or the environment)")
    }
    return value
  }

  enum ConfigError: Error, CustomStringConvertible {
    case missingRequiredField(String)
    case invalidPort(envVar: String, value: Int)

    var description: String {
      switch self {
      case .missingRequiredField(let field):
        return "Missing required field: \(field)"
      case .invalidPort(let envVar, let port):
        return "\(envVar): \(port) is invalid. Must be between 1 and 65535"
      }
    }
  }
}
