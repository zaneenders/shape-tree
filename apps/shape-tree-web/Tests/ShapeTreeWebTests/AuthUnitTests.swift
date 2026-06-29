import Foundation
import Testing

@testable import ShapeTreeWebAuth
@testable import ShapeTreeEmail

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

  @Test func normalizedWasmNextPathAcceptsSafePaths() {
    #expect(AuthEmail.normalizedWasmNextPath("/") == "/")
    #expect(AuthEmail.normalizedWasmNextPath("/posts/secret") == "/posts/secret")
  }

  @Test func normalizedWasmNextPathRejectsUnsafePaths() {
    #expect(AuthEmail.normalizedWasmNextPath(nil) == nil)
    #expect(AuthEmail.normalizedWasmNextPath("//evil.com") == nil)
    #expect(AuthEmail.normalizedWasmNextPath("http://evil.com") == nil)
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
