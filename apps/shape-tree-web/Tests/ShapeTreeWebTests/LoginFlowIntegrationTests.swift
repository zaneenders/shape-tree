import Configuration
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdAuth
import HummingbirdTesting
import Logging
import NIOCore
import PostgresNIO
import ShapeTreeWebCore
import Testing

@testable import ShapeTreeWeb
@testable import ShapeTreeWebAuth
@testable import ShapeTreeWebEmail

/// Suite-level gate: enabled when `SMTP_INTEGRATION_TEST=true` and SMTP/IMAP
/// credentials are available in the environment or `.env`.
private func loginFlowSuiteEnabled() -> Bool {
  let values = SMTPSettings.mergedEnvironment()
  guard values["SMTP_INTEGRATION_TEST"]?.lowercased() == "true" else {
    return false
  }
  guard SMTPSettings.loadFromEnvironment() != nil,
    IMAPSettings.loadFromEnvironment() != nil
  else { return false }
  let recipient = values["SMTP_TEST_TO"] ?? values["SMTP_FROM"]
  return !(recipient ?? "").isEmpty
}

/// Full end-to-end login flow test against a real Postgres + SMTP/IMAP provider.
///
/// Exercises the entire magic-link login flow in-process via Hummingbird's
/// `.router` test framework:
///
/// 1. Asserts a private wasm route returns 404 when unauthenticated.
/// 2. Asserts the navigation does not show the private directory when unauthenticated.
/// 3. Triggers a login email via POST /auth/login (legacy `/posts/` next is normalized).
/// 4. Polls IMAP for the login email and extracts the token from the link.
/// 5. Verifies GET /auth/verify returns the slim shell with token for client-side confirm UI.
/// 6. Verifies POST /auth/verify and captures the session cookie (wasm redirect target).
/// 7. Asserts the private wasm post shell is reachable when authenticated.
/// 8. Asserts the navigation now shows the private directory.
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
  func fullLoginFlowShowsPrivateContentAfterAuthentication() async throws {
    let values = SMTPSettings.mergedEnvironment()
    let logger = Logger(label: "test.login-flow")

    guard let smtpSettings = SMTPSettings.loadFromEnvironment() else {
      Issue.record("SMTP settings missing despite integration gate")
      return
    }
    guard let imapSettings = IMAPSettings.loadFromEnvironment() else {
      Issue.record("IMAP settings missing despite integration gate")
      return
    }

    let config = try await Self.makeConfig()
    let postgresSettings = try PostgresSettings.load(from: config)
    let testEmail = smtpSettings.fromAddress

    let port = try config.requiredInt(forKey: "PORT")
    let siteURL = "http://test-\(UUID().uuidString.prefix(8)):\(port)"
    let mailbox = values["IMAP_MAILBOX"] ?? "INBOX"
    let fetchLimit = max(Int(values["IMAP_FETCH_LIMIT"] ?? "") ?? 20, 1)
    let timeoutSeconds = max(Int(values["IMAP_ROUND_TRIP_TIMEOUT_SECONDS"] ?? "") ?? 90, 1)
    let pollSeconds = max(Int(values["IMAP_ROUND_TRIP_POLL_SECONDS"] ?? "") ?? 3, 1)

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

      let contentDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("login-flow-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(
        at: contentDir, withIntermediateDirectories: true)
      let contentMarker = UUID().uuidString
      try Self.createTestContent(at: contentDir, marker: contentMarker)
      defer { try? FileManager.default.removeItem(at: contentDir) }

      let store = try ContentStore(
        contentDirectory: contentDir,
        indexSlug: "Home",
        loginSlug: "login",
        privateDirectories: ["Private"]
      )
      let secretSlug = "secret"

      let auth = AuthServices(
        database: database,
        persist: persist,
        settings: AuthSettings(),
        smtp: smtpSettings,
        siteURL: siteURL,
        secureCookies: false
      )

      let router = Router(context: AppRequestContext.self)
      ShapeTreeWeb.configureRouter(
        router,
        store: store,
        indexSlug: "Home",
        auth: auth
      )

      let app = Application(router: router)

      try await app.test(.router) { client in
        let wasmPostPath = "/wasm/posts/\(secretSlug)"

        // 1. Unauthenticated: private wasm route returns 404 (hidden, not redirected).
        try await client.execute(uri: wasmPostPath, method: .get) { response in
          #expect(response.status == .notFound)
        }

        // 1b. Unauthenticated: legacy post URL stays hidden.
        try await client.execute(uri: "/posts/\(secretSlug)", method: .get) { response in
          #expect(response.status == .notFound)
        }

        // 2. Unauthenticated: nav omits private content.
        try await client.execute(uri: "/api/get-nav-content", method: .get) { response in
          #expect(response.status == .ok)
          let body = String(buffer: response.body)
          let payload = try JSONDecoder().decode(NavContentResponse.self, from: Data(body.utf8))
          #expect(!payload.groups.flatMap(\.items).contains { $0.slug == secretSlug })
        }

        // 3. Trigger login email.
        let loginBody = "email=\(testEmail)&next=/posts/\(secretSlug)"
        try await client.execute(
          uri: "/auth/login",
          method: .post,
          headers: [.contentType: "application/x-www-form-urlencoded"],
          body: ByteBuffer(string: loginBody)
        ) { response in
          #expect(response.status == .ok)
          #expect(response.headers[.contentType] == "application/json; charset=utf-8")
          let body = String(buffer: response.body)
          #expect(body.contains("\"ok\":true"))
        }

        // 4. Poll IMAP for the login email and extract the token.
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

        // 5. GET /auth/verify returns the slim shell with token for client-side confirm UI.
        try await client.execute(
          uri: "/auth/verify?token=\(rawToken)&next=/posts/\(secretSlug)",
          method: .get
        ) { response in
          #expect(response.status == .ok)
          let body = String(buffer: response.body)
          #expect(body.contains("data-boot-verify=\"true\""))
          #expect(body.contains("data-verify-token=\"\(rawToken)\""))
          #expect(body.contains("/assets/client/bootstrap.js"))
        }

        // 6. POST /auth/verify with token.
        var sessionCookie: String?
        let verifyBody = "token=\(rawToken)&next=/posts/\(secretSlug)"
        try await client.execute(
          uri: "/auth/verify",
          method: .post,
          headers: [
            .contentType: "application/x-www-form-urlencoded",
            .accept: "application/json",
          ],
          body: ByteBuffer(string: verifyBody)
        ) { response in
          #expect(response.status == .ok)
          #expect(response.headers[.contentType] == "application/json; charset=utf-8")
          let body = String(buffer: response.body)
          #expect(body.contains("\(wasmPostPath)?signed-in=1"))
          if let setCookie = response.headers[.setCookie] {
            sessionCookie = Self.parseSessionCookie(setCookie)
          }
        }

        guard let sessionCookie, !sessionCookie.isEmpty else {
          Issue.record("No session cookie set after verify")
          return
        }

        // 7. Authenticated: legacy post URL redirects to the wasm route.
        try await client.execute(
          uri: "/posts/\(secretSlug)",
          method: .get,
          headers: [.cookie: sessionCookie]
        ) { response in
          #expect(response.status == .seeOther)
          #expect(response.headers[.location] == wasmPostPath)
        }

        // 7b. Authenticated: wasm post shell boots client-side content.
        try await client.execute(
          uri: wasmPostPath,
          method: .get,
          headers: [.cookie: sessionCookie]
        ) { response in
          #expect(response.status == .ok)
          let body = String(buffer: response.body)
          #expect(body.contains("data-initial-wasm-slug=\"\(secretSlug)\""))
          #expect(body.contains("id=\"styled-navigation\""))
          #expect(!body.contains(contentMarker))
        }

        // 8. Authenticated: nav now includes private content.
        try await client.execute(
          uri: "/api/get-nav-content",
          method: .get,
          headers: [.cookie: sessionCookie]
        ) { response in
          #expect(response.status == .ok)
          let body = String(buffer: response.body)
          let payload = try JSONDecoder().decode(NavContentResponse.self, from: Data(body.utf8))
          #expect(payload.groups.flatMap(\.items).contains { $0.slug == secretSlug })
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

  private static func createTestContent(at dir: URL, marker: String) throws {
    let homeMarkdown = "---\ntitle: Test Site\n---\nWelcome to the test site."
    try homeMarkdown.write(
      to: dir.appendingPathComponent("Home.md"),
      atomically: true,
      encoding: .utf8
    )
    let privateDir = dir.appendingPathComponent("Private", isDirectory: true)
    try FileManager.default.createDirectory(
      at: privateDir,
      withIntermediateDirectories: true
    )
    let secretMarkdown = "---\ntitle: \(marker)\n---\n\(marker)"
    try secretMarkdown.write(
      to: privateDir.appendingPathComponent("secret.md"),
      atomically: true,
      encoding: .utf8
    )
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
