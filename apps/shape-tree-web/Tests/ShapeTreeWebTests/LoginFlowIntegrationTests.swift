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

/// Full end-to-end login flow test against a real Postgres + SMTP/IMAP provider.
///
/// Exercises the entire magic-link login flow in-process via Hummingbird's
/// `.router` test framework:
///
/// 1. Asserts a private post is hidden (redirect to /login) when unauthenticated.
/// 2. Asserts the navigation does not show the private directory when unauthenticated.
/// 3. Triggers a login email via POST /auth/login.
/// 4. Polls IMAP for the login email and extracts the token from the link.
/// 5. Verifies the token via POST /auth/verify and captures the session cookie.
/// 6. Asserts the private post is now visible (200 OK with content).
/// 7. Asserts the navigation now shows the private directory.
///
/// Required environment variables:
/// - `SMTP_INTEGRATION_TEST=true`
/// - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM`
/// - `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`
/// - IMAP uses the same credentials; optional `IMAP_HOST`, `IMAP_PORT`, `IMAP_MAILBOX`
/// - `SMTP_TEST_TO` — defaults to `SMTP_FROM` (send to self)
///
/// ```console
/// SMTP_INTEGRATION_TEST=true swift test --filter LoginFlowIntegrationTests
/// ```
@Suite(.timeLimit(.minutes(2)))
struct LoginFlowIntegrationTests {
  @Test(.disabled(if: !integrationEnabled()))
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
        privateDirectories: ["Private"]
      )
      let initial = store.indexPost ?? store.publishedPosts.first!
      let secretSlug = "secret"

      let auth = AuthServices(
        database: database,
        persist: persist,
        settings: AuthSettings(),
        smtp: smtpSettings,
        siteURL: siteURL,
        secureCookies: false,
        privateDirectories: ["Private"]
      )
      let rateLimiter = LoginRateLimiter()

      let router = Router(context: AppRequestContext.self)
      ShapeTreeWeb.configureRouter(
        router,
        store: store,
        initial: initial,
        indexSlug: "Home",
        auth: auth,
        rateLimiter: rateLimiter
      )

      let app = Application(router: router)

      try await app.test(.router) { client in
        let htmxHeader = HTTPField.Name("HX-Request")!

        // 1. Unauthenticated: private post redirects to login.
        try await client.execute(uri: "/posts/\(secretSlug)", method: .get) { response in
          #expect(response.status == .seeOther)
          #expect(response.headers[.location]?.contains("/login") == true)
        }

        // 2. Unauthenticated: nav omits private content.
        try await client.execute(
          uri: "/htmx/content/nav",
          method: .get,
          headers: [htmxHeader: "true"]
        ) { response in
          #expect(response.status == .ok)
          let body = String(buffer: response.body)
          #expect(!body.contains(contentMarker))
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
          let body = String(buffer: response.body)
          #expect(body.contains("Check your email"))
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

        // 5. GET /auth/verify shows the confirm page.
        try await client.execute(
          uri: "/auth/verify?token=\(rawToken)&next=/posts/\(secretSlug)",
          method: .get
        ) { response in
          #expect(response.status == .ok)
          let body = String(buffer: response.body)
          #expect(body.contains("Confirm sign in"))
        }

        // 6. POST /auth/verify with token + Origin header (same-origin check).
        var sessionCookie: String?
        let verifyBody = "token=\(rawToken)&next=/posts/\(secretSlug)"
        try await client.execute(
          uri: "/auth/verify",
          method: .post,
          headers: [
            .contentType: "application/x-www-form-urlencoded",
            .origin: siteURL,
          ],
          body: ByteBuffer(string: verifyBody)
        ) { response in
          #expect(response.status == .seeOther)
          #expect(response.headers[.location] == "/posts/\(secretSlug)")
          if let setCookie = response.headers[.setCookie] {
            sessionCookie = Self.parseSessionCookie(setCookie)
          }
        }

        guard let sessionCookie, !sessionCookie.isEmpty else {
          Issue.record("No session cookie set after verify")
          return
        }

        // 7. Authenticated: private post is now visible.
        try await client.execute(
          uri: "/posts/\(secretSlug)",
          method: .get,
          headers: [.cookie: sessionCookie]
        ) { response in
          #expect(response.status == .ok)
          let body = String(buffer: response.body)
          #expect(body.contains(contentMarker))
        }

        // 8. Authenticated: nav now includes private content.
        try await client.execute(
          uri: "/htmx/content/nav",
          method: .get,
          headers: [htmxHeader: "true", .cookie: sessionCookie]
        ) { response in
          #expect(response.status == .ok)
          let body = String(buffer: response.body)
          #expect(body.contains(contentMarker))
        }
      }
    }
  }

  // MARK: - Helpers

  private static func integrationEnabled() -> Bool {
    let values = SMTPSettings.mergedEnvironment()
    guard values["SMTP_INTEGRATION_TEST"]?.lowercased() == "true" else {
      return false
    }
    guard SMTPSettings.loadFromEnvironment() != nil,
      IMAPSettings.loadFromEnvironment() != nil
    else { return false }
    guard
      let host = values["PGHOST"], !host.isEmpty,
      let portStr = values["PGPORT"], let port = Int(portStr),
      port >= 1, port <= 65535,
      let user = values["PGUSER"], !user.isEmpty,
      let password = values["PGPASSWORD"], !password.isEmpty,
      let database = values["PGDATABASE"], !database.isEmpty
    else { return false }
    let recipient = values["SMTP_TEST_TO"] ?? values["SMTP_FROM"]
    return !(recipient ?? "").isEmpty
  }

  private static func ensureUser(
    database: PostgresAuthDatabase,
    email: String,
    logger: Logger
  ) async throws -> User {
    let normalized = AuthMiddleware.normalizedEmail(email)
    if let existing = try await database.user(email: normalized, logger: logger) {
      return existing
    }
    return try await database.createUser(email: normalized, logger: logger)
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
}
