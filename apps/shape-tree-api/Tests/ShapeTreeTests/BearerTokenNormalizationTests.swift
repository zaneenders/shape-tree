import Foundation
import ShapeTreeClient
import Testing

@Suite struct BearerTokenNormalizationTests {

  @Test func stripsSingleBearerPrefix() {
    #expect(ShapeTreeAPIClientMiddleware.normalizedBearerJWT("Bearer abc.def.ghi") == "abc.def.ghi")
  }

  @Test func stripsDoubleBearerPrefix() {
    #expect(ShapeTreeAPIClientMiddleware.normalizedBearerJWT("Bearer Bearer abc") == "abc")
  }

  @Test func stripsAuthorizationHeaderLine() {
    #expect(
      ShapeTreeAPIClientMiddleware.normalizedBearerJWT("Authorization: Bearer abc.def") == "abc.def")
  }

  @Test func trimsWhitespace() {
    #expect(ShapeTreeAPIClientMiddleware.normalizedBearerJWT("  Bearer  xyz  ") == "xyz")
  }

  @Test func stripsEmbeddedNewlinesFromWrappedToken() {
    // ES256-shaped compact JWS (segments are syntactic only — normalization only strips whitespace).
    let headerJSON =
      #"{"alg":"ES256","kid":"AaECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8","typ":"JWT"}"#
    let payloadJSON =
      #"{"exp":1700000900,"iat":1700000000,"jti":"norm-test","sub":"AaECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"}"#
    let h = Data(headerJSON.utf8).base64URLEncodedStringNoPadding()
    let p = Data(payloadJSON.utf8).base64URLEncodedStringNoPadding()
    let s = Data(repeating: 0xAB, count: 64).base64URLEncodedStringNoPadding()
    let compact = "\(h).\(p).\(s)"

    // Simulates terminal word-wrap: a JWT split across lines by the terminal.
    let wrapped = stride(from: 0, to: compact.count, by: 54).map { offset in
      let start = compact.index(compact.startIndex, offsetBy: offset)
      let end = compact.index(start, offsetBy: min(54, compact.distance(from: start, to: compact.endIndex)))
      return String(compact[start..<end])
    }.joined(separator: "\n      ")

    let normalized = ShapeTreeAPIClientMiddleware.normalizedBearerJWT(wrapped)
    #expect(!normalized.contains { $0.isWhitespace || $0.isNewline })
    #expect(normalized.components(separatedBy: ".").count == 3)
    #expect(normalized == compact)
  }
}
