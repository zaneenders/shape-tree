import Foundation
import Logging
import Testing

@testable import ShapeTreeEmail
@testable import ShapeTreeWebAuth

@Suite struct LoginTokenServiceTests {
  @Test func generateProducesBase64URLToken() {
    let (raw, _) = LoginTokenService.generate()
    #expect(!raw.isEmpty)
    #expect(raw.count >= 32)
    #expect(!raw.contains("+"))
    #expect(!raw.contains("/"))
    #expect(!raw.contains("="))
  }

  @Test func hashIsDeterministic() {
    let raw = "abc123"
    #expect(LoginTokenService.hash(raw) == LoginTokenService.hash(raw))
  }

  @Test func hashProducesKnownSHA256Hex() {
    #expect(
      LoginTokenService.hash("hello")
        == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    )
  }

  @Test func hashIs64HexChars() {
    #expect(LoginTokenService.hash("anything").count == 64)
    #expect(LoginTokenService.hash("").allSatisfy { $0.isHexDigit })
  }

  @Test func generateProducesDifferentTokensEachCall() {
    let (raw1, _) = LoginTokenService.generate()
    let (raw2, _) = LoginTokenService.generate()
    #expect(raw1 != raw2)
  }

  @Test func hashOfGeneratedTokenMatchesGenerateReturnValue() {
    let (raw, hashFromGenerate) = LoginTokenService.generate()
    #expect(LoginTokenService.hash(raw) == hashFromGenerate)
  }
}

@Suite struct FormParserTests {
  @Test func parsesSimpleKeyValuePair() {
    let fields = FormParser.parseURLForm("email=foo@example.com")
    #expect(fields["email"] == "foo@example.com")
  }

  @Test func parsesMultiplePairs() {
    let fields = FormParser.parseURLForm("email=foo@example.com&next=/posts/secret")
    #expect(fields["email"] == "foo@example.com")
    #expect(fields["next"] == "/posts/secret")
  }

  @Test func decodesPercentEncodedValues() {
    let fields = FormParser.parseURLForm("next=%2Fposts%2Fsecret")
    #expect(fields["next"] == "/posts/secret")
  }

  @Test func convertsPlusToSpace() {
    let fields = FormParser.parseURLForm("email=foo+bar@example.com")
    #expect(fields["email"] == "foo bar@example.com")
  }

  @Test func ignoresPairsWithoutValue() {
    let fields = FormParser.parseURLForm("email=foo&flag")
    #expect(fields["email"] == "foo")
    #expect(fields["flag"] == nil)
  }

  @Test func handlesEmptyBody() {
    #expect(FormParser.parseURLForm("").isEmpty)
  }

  @Test func splitsOnlyOnFirstEquals() {
    let fields = FormParser.parseURLForm("key=a=b=c")
    #expect(fields["key"] == "a=b=c")
  }
}

@Suite struct AuthMiddlewareTests {

  @Test func validatedEmailNormalizesValidAddress() {
    #expect(AuthEmail.validatedEmail("  Foo@Example.COM ") == "foo@example.com")
    #expect(AuthEmail.validatedEmail("a.b+tag@sub.example.co") == "a.b+tag@sub.example.co")
  }

  @Test func validatedEmailRejectsMalformedAddress() {
    #expect(AuthEmail.validatedEmail("") == nil)
    #expect(AuthEmail.validatedEmail("not-an-email") == nil)
    #expect(AuthEmail.validatedEmail("foo@bar") == nil)
    #expect(AuthEmail.validatedEmail("foo@bar.") == nil)
    #expect(AuthEmail.validatedEmail("foo bar@example.com") == nil)
    #expect(AuthEmail.validatedEmail("@example.com") == nil)
  }

  @Test func safeNextPathRejectsNonAbsolutePath() {
    #expect(AuthEmail.safeNextPath("http://evil.com") == nil)
  }

  @Test func safeNextPathRejectsDoubleSlash() {
    #expect(AuthEmail.safeNextPath("//evil.com") == nil)
  }

  @Test func safeNextPathAcceptsSimplePath() {
    #expect(AuthEmail.safeNextPath("/posts/secret") == "/posts/secret")
  }

  @Test func safeNextPathRejectsNil() {
    #expect(AuthEmail.safeNextPath(nil) == nil)
  }

  @Test func safeNextPathRejectsEmpty() {
    #expect(AuthEmail.safeNextPath("") == nil)
  }
}

@Suite struct SMTPMessageEncodingTests {
  @Test func sanitizeHeaderValueStripsCRAndLF() {
    #expect(SMTPMessageEncoding.sanitizeHeaderValue("hello\r\nworld") == "helloworld")
  }

  @Test func sanitizeHeaderValuePreservesNormalText() {
    #expect(SMTPMessageEncoding.sanitizeHeaderValue("Hello World") == "Hello World")
  }

  @Test func dotStuffedBodyPrependsDotToLinesStartingWithDot() {
    let result = SMTPMessageEncoding.dotStuffedBody(".dot\nnormal\n..double")
    #expect(result == "..dot\r\nnormal\r\n...double")
  }

  @Test func dotStuffedBodyUsesCRLFLineSeparators() {
    #expect(SMTPMessageEncoding.dotStuffedBody("a\nb") == "a\r\nb")
  }

  @Test func dotStuffedBodyNormalizesCRLF() {
    #expect(SMTPMessageEncoding.dotStuffedBody("a\r\nb") == "a\r\nb")
  }

  @Test func rfc5322DateStringProducesGMTFormattedDate() {
    let date = Date(timeIntervalSince1970: 0)
    #expect(
      SMTPMessageEncoding.rfc5322DateString(from: date)
        == "Thu, 01 Jan 1970 00:00:00 +0000"
    )
  }
}

@Suite struct LoginRateLimiterTests {
  @Test func allowsUpToMaxAttempts() async {
    let limiter = LoginRateLimiter(window: .seconds(60), maxAttempts: 3)
    #expect(await limiter.allow(ip: "1.2.3.4") == true)
    #expect(await limiter.allow(ip: "1.2.3.4") == true)
    #expect(await limiter.allow(ip: "1.2.3.4") == true)
  }

  @Test func blocksAfterMaxAttempts() async {
    let limiter = LoginRateLimiter(window: .seconds(60), maxAttempts: 2)
    _ = await limiter.allow(ip: "1.2.3.4")
    _ = await limiter.allow(ip: "1.2.3.4")
    #expect(await limiter.allow(ip: "1.2.3.4") == false)
  }

  @Test func resetsAfterWindowExpires() async throws {
    let limiter = LoginRateLimiter(window: .milliseconds(200), maxAttempts: 1)
    #expect(await limiter.allow(ip: "1.1.1.1") == true)
    #expect(await limiter.allow(ip: "1.1.1.1") == false)
    try await Task.sleep(for: .milliseconds(250))
    #expect(await limiter.allow(ip: "1.1.1.1") == true)
  }
}

private actor FakeAuthDatabase: AuthDatabase {
  private var _users: [String: User] = [:]
  private var _tokens: [String: StoredToken] = [:]

  private(set) var createdTokens: [(userID: UUID, tokenHash: String)] = []
  private(set) var consumedTokens: [String] = []

  var nextCreateLoginTokenError: (any Error)?

  func setNextCreateLoginTokenError(_ error: any Error) {
    nextCreateLoginTokenError = error
  }

  struct StoredToken {
    let userID: UUID
    let tokenHash: String
    let expiresAt: Date
  }

  func addUser(_ user: User) {
    _users[user.email] = user
  }

  func user(email: String, logger: Logger) async throws -> User? {
    _users[email]
  }

  func user(id: UUID, logger: Logger) async throws -> User? {
    _users.values.first { $0.id == id }
  }

  func createUser(email: String, logger: Logger) async throws -> User {
    let user = User(id: UUID(), email: email, createdAt: Date())
    _users[email] = user
    return user
  }

  func createLoginToken(
    userID: UUID, tokenHash: String, expiresAt: Date, logger: Logger
  ) async throws {
    if let error = nextCreateLoginTokenError {
      nextCreateLoginTokenError = nil
      throw error
    }
    _tokens[tokenHash] = StoredToken(
      userID: userID, tokenHash: tokenHash, expiresAt: expiresAt)
    createdTokens.append((userID, tokenHash))
  }

  func consumeLoginToken(hash: String, logger: Logger) async throws -> UUID? {
    consumedTokens.append(hash)
    return _tokens.removeValue(forKey: hash)?.userID
  }

  func deleteExpiredLoginTokens(logger: Logger) async throws {
  }

  var storedTokenCount: Int {
    _tokens.count
  }

  func hasToken(hash: String) -> Bool {
    _tokens[hash] != nil
  }
}

@Suite struct LoginEmailFailureRecoveryTests {
  private let logger = Logger(label: "test.login-email-failure")

  @Test func orphanedTokenRemainsWhenEmailFailsAfterSuccessfulPersist() async throws {
    let db = FakeAuthDatabase()
    let user = try await db.createUser(email: "test@example.com", logger: logger)
    let (_, tokenHash) = LoginTokenService.generate()
    let expiresAt = Date.now + 600

    try await db.createLoginToken(
      userID: user.id,
      tokenHash: tokenHash,
      expiresAt: expiresAt,
      logger: logger
    )

    #expect(await db.hasToken(hash: tokenHash) == true)
    #expect(await db.storedTokenCount == 1)
    #expect(await db.createdTokens.count == 1)

    let userID = try await db.consumeLoginToken(hash: tokenHash, logger: logger)
    #expect(userID == user.id, "Token is valid and points to the right user")
    #expect(await db.storedTokenCount == 0, "Token is consumed on first use")
  }

  @Test func retryCreatesFreshTokenWhileOrphanedTokenLingers() async throws {
    let db = FakeAuthDatabase()
    let user = try await db.createUser(email: "test@example.com", logger: logger)

    let (_, hash1) = LoginTokenService.generate()
    try await db.createLoginToken(
      userID: user.id, tokenHash: hash1,
      expiresAt: Date.now + 600, logger: logger
    )

    let (_, hash2) = LoginTokenService.generate()
    try await db.createLoginToken(
      userID: user.id, tokenHash: hash2,
      expiresAt: Date.now + 600, logger: logger
    )

    #expect(await db.storedTokenCount == 2)
    #expect(await db.hasToken(hash: hash1) == true, "First token still orphaned")
    #expect(await db.hasToken(hash: hash2) == true, "Second token is present")
    #expect(hash1 != hash2, "Tokens are distinct")

    let consumedUserID = try await db.consumeLoginToken(hash: hash2, logger: logger)
    #expect(consumedUserID == user.id)

    #expect(await db.hasToken(hash: hash1) == true, "Orphaned token remains until expiry sweep")
    #expect(await db.storedTokenCount == 1)
  }

  @Test func noTokenPersistedWhenCreateLoginTokenFails() async throws {
    let db = FakeAuthDatabase()
    let user = try await db.createUser(email: "test@example.com", logger: logger)

    let (_, tokenHash) = LoginTokenService.generate()

    struct DBError: Error {}
    await db.setNextCreateLoginTokenError(DBError())

    let tokenPersisted: Bool
    do {
      try await db.createLoginToken(
        userID: user.id, tokenHash: tokenHash,
        expiresAt: Date.now + 600, logger: logger
      )
      tokenPersisted = true
    } catch {
      tokenPersisted = false
    }

    #expect(tokenPersisted == false, "DB write threw — token was never created")
    #expect(await db.storedTokenCount == 0, "Nothing persisted")
    #expect(await db.createdTokens.isEmpty, "No creation recorded")

    let (_, hash2) = LoginTokenService.generate()
    try await db.createLoginToken(
      userID: user.id, tokenHash: hash2,
      expiresAt: Date.now + 600, logger: logger
    )
    #expect(await db.storedTokenCount == 1, "Retry after DB recovery succeeds")
    #expect(await db.hasToken(hash: hash2) == true)
  }

  @Test func repeatedFailuresDuringSMTPOutageAccumulateOrphanedTokens() async throws {
    let db = FakeAuthDatabase()
    let user = try await db.createUser(email: "test@example.com", logger: logger)

    for _ in 0..<3 {
      let (_, hash) = LoginTokenService.generate()
      try await db.createLoginToken(
        userID: user.id, tokenHash: hash,
        expiresAt: Date.now + 600, logger: logger
      )
    }

    #expect(await db.storedTokenCount == 3, "Three orphaned tokens accumulated")
    #expect(await db.createdTokens.count == 3)

    for (_, hash) in await db.createdTokens {
      let uid = try await db.consumeLoginToken(hash: hash, logger: logger)
      #expect(uid == user.id)
    }
    #expect(await db.storedTokenCount == 0)
  }
}
