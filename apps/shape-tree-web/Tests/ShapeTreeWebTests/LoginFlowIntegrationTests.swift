import Configuration
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdAuth
import HummingbirdTesting
import Logging
import NIOCore
import PostgresNIO
import Testing

@testable import ShapeTreeEmail
@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth

/// Suite-level gate: enabled when `SMTP_INTEGRATION_TEST=true` and SMTP/IMAP
/// credentials are present (process env or `.env` via swift-configuration in tests).
private func loginFlowSuiteEnabled() -> Bool {
  guard ProcessInfo.processInfo.environment["SMTP_INTEGRATION_TEST"]?.lowercased() == "true" else {
    return false
  }
  let required = ["SMTP_HOST", "SMTP_PORT", "SMTP_USERNAME", "SMTP_PASSWORD", "SMTP_FROM"]
  let env = ProcessInfo.processInfo.environment
  return required.allSatisfy { !(env[$0] ?? "").isEmpty }
}

/// Full end-to-end login flow test against a real Postgres + SMTP/IMAP provider.
///
/// Exercises the magic-link login flow in-process via Hummingbird's `.router` test framework:
///
/// 1. Asserts fit-viewer assets redirect to login when unauthenticated.
/// 2. Triggers a login email via POST /auth/login.
/// 3. Polls IMAP for the login email and extracts the token from the link.
/// 4. Verifies GET /auth/verify returns the verify page.
/// 5. Verifies POST /auth/verify and captures the session cookie.
/// 6. Asserts fit-viewer assets are reachable when authenticated.
///
/// The suite automatically starts the docker-compose `postgres` service in
/// ``init`` and stops it in ``deinit`` — no manual setup needed. SMTP/IMAP
/// credentials are read from `.env`.
///
/// Set `SMTP_INTEGRATION_TEST=true` to enable the suite (skipped otherwise):
///
/// ```console
/// SMTP_INTEGRATION_TEST=true swift test --filter LoginFlowIntegrationTests
/// ```
@Suite(.serialized, .timeLimit(.minutes(2)), .disabled(if: !loginFlowSuiteEnabled()))
struct LoginFlowIntegrationTests: ~Copyable {

  /// True when this instance started Postgres (and should stop it in deinit).
  private let startedPostgres: Bool

  init() async throws {
    startedPostgres = try await Self.startPostgres()
  }

  deinit {
    if startedPostgres {
      Self.stopPostgres()
    }
  }

  // MARK: - Tests

  @Test
  func fullLoginFlowUnlocksFitViewerAfterAuthentication() async throws {
    let logger = Logger(label: "test.login-flow")

    let config = try await Self.makeConfig()
    guard SMTPSettings.integrationTestEnabled(in: config) else {
      Issue.record("SMTP/IMAP integration settings missing despite integration gate")
      return
    }
    guard let smtpSettings = SMTPSettings.load(from: config) else {
      Issue.record("SMTP settings missing despite integration gate")
      return
    }
    guard let imapSettings = IMAPSettings.load(from: config) else {
      Issue.record("IMAP settings missing despite integration gate")
      return
    }

    let postgresSettings = try PostgresSettings.load(from: config)
    let testEmail = smtpSettings.fromAddress

    let port = try config.requiredInt(forKey: "PORT")
    let siteURL = "http://test-\(UUID().uuidString.prefix(8)):\(port)"
    let mailbox = config.string(forKey: "IMAP_MAILBOX", isSecret: false) ?? "INBOX"
    let fetchLimit = max(config.int(forKey: "IMAP_FETCH_LIMIT") ?? 20, 1)
    let timeoutSeconds = max(config.int(forKey: "IMAP_ROUND_TRIP_TIMEOUT_SECONDS") ?? 90, 1)
    let pollSeconds = max(config.int(forKey: "IMAP_ROUND_TRIP_POLL_SECONDS") ?? 3, 1)

    let staticRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("login-flow-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: staticRoot, withIntermediateDirectories: true)
    try Data([0x00, 0x61, 0x73, 0x6D]).write(to: staticRoot.appendingPathComponent("FitViewer.wasm"))
    defer { try? FileManager.default.removeItem(at: staticRoot) }

    let pgClient = PostgresClient(configuration: postgresSettings.configuration)
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { await pgClient.run() }
      defer { group.cancelAll() }

      try await Migrations.run(client: pgClient, logger: logger)

      let database = PostgresAuthDatabase(client: pgClient)
      let persist = PostgresPersistDriver(client: pgClient, logger: logger)
      try await database.deleteExpiredLoginTokens(logger: logger)

      let user = try await Self.ensureUser(
        database: database, email: testEmail, logger: logger)
      logger.info("Test user: \(user.email) (\(user.id))")

      let auth = AuthServices(
        database: database,
        persist: persist,
        settings: AuthSettings(),
        config: config,
        siteURL: siteURL,
        secureCookies: false
      )

      let router = Router(context: AppRequestContext.self)
      AuthRoutes.addSessionMiddleware(to: router, auth: auth)
      AuthRoutes.addRoutes(
        to: router,
        auth: auth,
        rateLimiter: LoginRateLimiter(),
        spaLoginPage: { _ in Response(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "login"))) },
        spaVerifyPage: { _, _ in Response(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "verify"))) },
        spaCheckEmailPage: { Response(status: .ok, body: .init(byteBuffer: ByteBuffer(string: "check-email"))) }
      )
      FitProtectedRoutes.register(on: router, staticRoot: staticRoot.path)

      let app = Application(router: router)

      try await app.test(.router) { client in
        let nextPath = "/"

        // 1. Unauthenticated: fit viewer redirects to login.
        try await client.execute(uri: "/FitViewer.wasm", method: .get) { response in
          #expect(response.status == .seeOther)
          #expect(response.headers[.location]?.hasPrefix("/login") == true)
        }

        // 2. Trigger login email.
        let loginBody = "email=\(testEmail)&next=\(nextPath)"
        try await client.execute(
          uri: "/auth/login",
          method: .post,
          headers: [.contentType: "application/x-www-form-urlencoded"],
          body: ByteBuffer(string: loginBody)
        ) { response in
          #expect(response.status == .seeOther)
          #expect(response.headers[.location] == "/auth/check-email")
        }

        // 3. Poll IMAP for the login email and extract the token.
        let emailSubject = "Sign in to \(siteURL)"
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        var rawToken: String?

        while Date() < deadline {
          let messages = try await IMAPClient.fetchRecent(
            settings: imapSettings.connection,
            mailbox: mailbox,
            limit: fetchLimit
          )
          if let msg = messages.first(where: { $0.subject == emailSubject }),
            let body = msg.body
          {
            rawToken = Self.extractToken(from: body)
            if rawToken != nil { break }
          }
          try await Task.sleep(for: .seconds(pollSeconds))
        }

        guard let rawToken else {
          Issue.record("Login email not found in \(mailbox) within \(timeoutSeconds)s")
          return
        }

        // 4. GET /auth/verify returns the verify page.
        try await client.execute(
          uri: "/auth/verify?token=\(rawToken)&next=\(nextPath)",
          method: .get
        ) { response in
          #expect(response.status == .ok)
        }

        // 5. POST /auth/verify with token.
        var sessionCookie: String?
        let verifyBody = "token=\(rawToken)&next=\(nextPath)"
        try await client.execute(
          uri: "/auth/verify",
          method: .post,
          headers: [.contentType: "application/x-www-form-urlencoded"],
          body: ByteBuffer(string: verifyBody)
        ) { response in
          #expect(response.status == .seeOther)
          #expect(response.headers[.location] == "/?signed-in=1")
          if let setCookie = response.headers[.setCookie] {
            sessionCookie = Self.parseSessionCookie(setCookie)
          }
        }

        guard let sessionCookie, !sessionCookie.isEmpty else {
          Issue.record("No session cookie set after verify")
          return
        }

        // 6. Authenticated: fit viewer wasm is available.
        try await client.execute(
          uri: "/FitViewer.wasm",
          method: .get,
          headers: [.cookie: sessionCookie]
        ) { response in
          #expect(response.status == .ok)
          #expect(response.headers[.contentType] == "application/wasm")
        }
      }
    }
  }

  @Test
  func consumeLoginTokenIsAtomicUnderConcurrency() async throws {
    let logger = Logger(label: "test.token-atomicity")

    let config = try await Self.makeConfig()
    let postgresSettings = try PostgresSettings.load(from: config)

    let pgClient = PostgresClient(configuration: postgresSettings.configuration)
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { await pgClient.run() }
      defer { group.cancelAll() }

      try await Migrations.run(client: pgClient, logger: logger)
      let database = PostgresAuthDatabase(client: pgClient)
      try await database.deleteExpiredLoginTokens(logger: logger)

      let email = "token-atomicity-\(UUID().uuidString.prefix(8))@test.example"
      let user = try await Self.ensureUser(
        database: database, email: email, logger: logger)

      let rawToken = "test-token-\(UUID().uuidString)"
      let tokenHash = LoginTokenService.hash(rawToken)
      let expiresAt = Date.now + 300

      try await database.createLoginToken(
        userID: user.id,
        tokenHash: tokenHash,
        expiresAt: expiresAt,
        logger: logger
      )

      async let first = database.consumeLoginToken(hash: tokenHash, logger: logger)
      async let second = database.consumeLoginToken(hash: tokenHash, logger: logger)
      let (result1, result2) = try await (first, second)

      let successes = [result1, result2].compactMap { $0 }
      #expect(successes.count == 1)
      #expect(successes.first == user.id)

      let third = try await database.consumeLoginToken(hash: tokenHash, logger: logger)
      #expect(third == nil)
    }
  }

  // MARK: - Docker lifecycle

  /// Returns `true` if this call started Postgres (caller should stop it later),
  /// `false` if it was already running.
  private static func startPostgres() async throws -> Bool {
    let compose = composeFilePath()

    if isPostgresRunning(compose: compose) {
      return false
    }

    let logger = Logger(label: "test.docker")
    logger.info("Starting docker-compose postgres…")

    try runProcess("/usr/local/bin/docker", ["compose", "-f", compose, "up", "-d", "postgres"])

    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
      if pgIsReady(compose: compose) {
        logger.info("Postgres is ready")
        return true
      }
      try await Task.sleep(for: .seconds(1))
    }
    throw PostgresStartupError("Postgres did not become ready within 30s")
  }

  /// Best-effort stop from `deinit` (can't be async until Swift 6.4).
  private static func stopPostgres() {
    let compose = composeFilePath()
    let logger = Logger(label: "test.docker")
    logger.info("Stopping docker-compose postgres")
    _ = try? runProcess("/usr/local/bin/docker", ["compose", "-f", compose, "stop", "postgres"])
  }

  private static func isPostgresRunning(compose: String) -> Bool {
    guard
      let output = try? runProcessCapture(
        "/usr/local/bin/docker",
        ["compose", "-f", compose, "ps", "postgres", "--format", "json"]
      )
    else { return false }
    return output.contains("\"running\"") || output.contains("\"State\":\"running\"")
      || output.contains("\"status\":\"running\"")
  }

  private static func pgIsReady(compose: String) -> Bool {
    let code = try? runProcessExitCode(
      "/usr/local/bin/docker",
      ["compose", "-f", compose, "exec", "-T", "postgres", "pg_isready", "-U", "shape_tree"])
    return code == 0
  }

  private static func composeFilePath() -> String {
    FileManager.default.currentDirectoryPath + "/../../docker-compose.yml"
  }

  private enum PostgresStartupError: Error, CustomStringConvertible {
    case message(String)
    init(_ text: String) { self = .message(text) }
    var description: String {
      if case .message(let text) = self { text } else { "PostgresStartupError" }
    }
  }

  // MARK: - Config

  /// Builds a `ConfigReader` that reads from the process environment and `.env`,
  /// overriding `PGHOST` to `127.0.0.1` so the test can reach the docker-compose
  /// Postgres port-forward (the `.env` default `postgres` only resolves inside Docker).
  private static func makeConfig() async throws -> ConfigReader {
    let secretKeys = SecretsSpecifier<String, String>.specific([
      "PGPASSWORD", "SMTP_PASSWORD",
    ])
    var env = ProcessInfo.processInfo.environment
    env["PGHOST"] = "127.0.0.1"
    return ConfigReader(providers: [
      EnvironmentVariablesProvider(environmentVariables: env, secretsSpecifier: secretKeys),
      try await EnvironmentVariablesProvider(
        environmentFilePath: ".env",
        allowMissing: true,
        secretsSpecifier: secretKeys
      ),
    ])
  }

  // MARK: - Helpers

  private static func ensureUser(
    database: PostgresAuthDatabase,
    email: String,
    logger: Logger
  ) async throws -> User {
    guard let email = AuthEmail.validatedEmail(email) else {
      throw AuthEmailError.invalid
    }
    if let existing = try await database.user(email: email, logger: logger) {
      return existing
    }
    return try await database.createUser(email: email, logger: logger)
  }

  private static func extractToken(from body: String) -> String? {
    let prefix = "/auth/verify?token="
    guard let range = body.range(of: prefix) else { return nil }
    let afterPrefix = body[range.upperBound...]
    let endSet = CharacterSet(charactersIn: "&\n\r\t ")
    let endRange = afterPrefix.rangeOfCharacter(from: endSet)?.lowerBound ?? afterPrefix.endIndex
    return String(afterPrefix[..<endRange])
  }

  private static func parseSessionCookie(_ setCookie: String) -> String {
    let parts = setCookie.split(separator: ";")
    guard let first = parts.first else { return "" }
    return String(first).trimmingCharacters(in: .whitespaces)
  }

  // MARK: - Process helpers

  @discardableResult
  private static func runProcess(_ executable: String, _ args: [String]) throws -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
    process.standardError = FileHandle(forWritingAtPath: "/dev/null")
    try process.run()
    process.waitUntilExit()
    return process
  }

  private static func runProcessExitCode(_ executable: String, _ args: [String]) throws -> Int32 {
    try runProcess(executable, args).terminationStatus
  }

  private static func runProcessCapture(_ executable: String, _ args: [String]) throws -> String {
    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    process.standardOutput = pipe
    process.standardError = FileHandle(forWritingAtPath: "/dev/null")
    try process.run()
    process.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  }
}
