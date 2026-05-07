import ArgumentParser
import Configuration
import Foundation
import JWTKit
import OpenAPIAsyncHTTPClient
import ShapeTreeClient

private struct MintHS256Claims: JWTPayload {
  var sub: SubjectClaim
  var iat: IssuedAtClaim
  var exp: ExpirationClaim

  func verify(using algorithm: some JWTAlgorithm) throws {
    try exp.verifyNotExpired()
  }
}

private enum LocalConfigKey {
  static let jwtSecret: ConfigKey = "jwt.secret"
}

private func jwtSecretFromConfigFile(path: String = "shape-tree-config.json") async throws -> String {
  let fileProvider = try await FileProvider<JSONSnapshot>(filePath: .init(path))
  let reader = ConfigReader(providers: [fileProvider])
  let secret = try await reader.fetchRequiredString(forKey: LocalConfigKey.jwtSecret)
  let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else {
    throw ValidationError("jwt.secret is empty in \(path)")
  }
  return trimmed
}

private func mintHS256JWT(secret: String, subject: String, ttlSeconds: TimeInterval) async throws -> String {
  let keys = JWTKeyCollection()
  await keys.add(hmac: HMACKey(from: secret), digestAlgorithm: .sha256)
  let now = Date()
  let payload = MintHS256Claims(
    sub: SubjectClaim(value: subject),
    iat: IssuedAtClaim(value: now),
    exp: ExpirationClaim(value: now.addingTimeInterval(ttlSeconds))
  )
  return try await keys.sign(payload)
}

@main struct ShapeTreeClientCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "ShapeTree OpenAPI client and JWT mint helper."
  )

  @Option(
    name: [.long],
    help: "ShapeTree server URL."
  )
  var server: String = "http://127.0.0.1:42069"

  @Option(
    name: [.short, .long],
    help: "Bearer JWT signed with the server's jwt.secret (HS256)."
  )
  var token: String = ""

  /// Reads `./shape-tree-config.json`, uses `jwt.secret`, mints **1 hour** token with random `sub`.
  @Flag(
    name: .customLong("mint-token"),
    help:
      "Read jwt.secret from ./shape-tree-config.json (cwd), print a 1-hour HS256 JWT with a random subject, then exit (nothing else required)."
  )
  var mintTokenFromConfig: Bool = false

  /// When non-empty, print an HS256 JWT for this secret (same string as `jwt.secret`) and exit.
  @Option(
    name: .customLong("print-hs256-jwt"),
    help:
      "Print a JWT signed with this HS256 secret (must match jwt.secret), then exit. Prefer --mint-token to avoid putting the secret on the command line."
  )
  var printHS256JWT: String = ""

  @Option(
    name: .customLong("mint-subject"),
    help: "Subject claim (`sub`) when using --print-hs256-jwt."
  )
  var mintSubject: String = "shape-tree-cli"

  @Option(
    name: .customLong("mint-ttl-seconds"),
    help: "Lifetime in seconds for the minted JWT (--print-hs256-jwt only; --mint-token is always 3600)."
  )
  var mintTTLSeconds: UInt64 = 3600

  mutating func run() async throws {
    let explicitSecret = printHS256JWT.trimmingCharacters(in: .whitespacesAndNewlines)

    if mintTokenFromConfig && !explicitSecret.isEmpty {
      throw ValidationError("Use either --mint-token or --print-hs256-jwt, not both.")
    }

    if mintTokenFromConfig {
      let secret = try await jwtSecretFromConfigFile()
      let subject = "shape-tree-\(UUID().uuidString)"
      let jwt = try await mintHS256JWT(secret: secret, subject: subject, ttlSeconds: 3600)
      print(jwt)
      return
    }

    if !explicitSecret.isEmpty {
      let ttl = TimeInterval(mintTTLSeconds)
      let jwt = try await mintHS256JWT(secret: explicitSecret, subject: mintSubject, ttlSeconds: ttl)
      print(jwt)
      return
    }

    guard let serverURL = URL(string: server) else {
      throw ValidationError("Invalid server URL: \(server)")
    }

    let transport = AsyncHTTPClientTransport()
    let middlewares = ShapeTreeAPIClientMiddleware.bearerJWT(token.isEmpty ? nil : token)
    let client = Client(
      serverURL: serverURL,
      transport: transport,
      middlewares: middlewares
    )

    // Create session (server uses its own configured model/LLM backend)
    print("Creating session...")
    let sessionResponse = try await client.createSession(
      .init(body: .json(.init()))
    )

    let session: Components.Schemas.CreateSessionResponse
    switch sessionResponse {
    case .ok(let ok):
      session = try ok.body.json
    case .badRequest(let err):
      let body = try err.body.json
      throw ValidationError("Error: \(body.error.message)")
    case .undocumented(let code, _):
      throw ValidationError("Error: server returned \(code)")
    }

    print("Session: \(session.id)")
    print("Type a message and press Enter.  /quit to exit.\n")

    // Interactive REPL
    while true {
      print("> ", terminator: "")
      guard let line = readLine() else { break }
      if line.isEmpty { continue }

      if line == "/quit" || line == "/exit" {
        print("Goodbye.")
        break
      }

      let completionResponse = try await client.runCompletion(
        path: .init(id: session.id),
        body: .json(.init(message: line))
      )

      switch completionResponse {
      case .ok(let ok):
        let result = try ok.body.json
        print(result.assistant)
      case .badRequest(let err):
        let body = try err.body.json
        print("Error: \(body.error.message)")
      case .notFound(let err):
        let body = try err.body.json
        print("Error: \(body.error.message)")
      case .internalServerError(let err):
        let body = try err.body.json
        print("Error: \(body.error.message)")
      case .undocumented(let code, _):
        print("Error: server returned \(code)")
      }
      print()
    }
  }
}
