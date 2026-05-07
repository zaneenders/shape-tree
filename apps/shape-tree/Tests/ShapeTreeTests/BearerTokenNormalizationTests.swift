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

  @Test func formatIssueDetectsJsonSnippet() {
    let pasted = #"{"jwt":{"secret":"abc"}}"#
    #expect(ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue(pasted) != nil)
  }

  @Test func formatIssueAcceptsThreeSegmentShape() {
    let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.signature"
    #expect(ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue(jwt) == nil)
  }

  @Test func formatIssueRejectsWrongSegmentCount() {
    #expect(ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue("only.two") != nil)
  }

  @Test func emptyTokenHasNoFormatIssue() {
    #expect(ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue("") == nil)
    #expect(ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue("   ") == nil)
  }
}
