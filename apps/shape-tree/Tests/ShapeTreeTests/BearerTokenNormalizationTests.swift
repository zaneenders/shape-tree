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

  @Test func stripsEmbeddedNewlinesFromWrappedToken() {
    // Simulates terminal word-wrap: a JWT split across lines by the terminal.
    let wrapped = """
      eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3NzgzNTQ1ODMuMDQzNDgzLCJzdWIiOiJzaGFwZS10
      cmVlLUFEN0JCN0Y3LUNDMzItNEM1Mi04ODA2LTIxQjRDOUFFNDc5QSIsImlhdCI6MTc3OD
      M1MDk4My4wNDM0ODN9.fpysfjm1T4gcy7HEpbkkrQpICf1B0hnVQN4xzF-qMjU
      """
    let normalized = ShapeTreeAPIClientMiddleware.normalizedBearerJWT(wrapped)
    // Should be one continuous string with no whitespace.
    #expect(!normalized.contains { $0.isWhitespace || $0.isNewline })
    // Should still have exactly 2 dots (3 segments).
    #expect(normalized.components(separatedBy: ".").count == 3)
    // Should be accepted by format check.
    #expect(ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue(wrapped) == nil)
  }

  @Test func emptyTokenHasNoFormatIssue() {
    #expect(ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue("") == nil)
    #expect(ShapeTreeAPIClientMiddleware.bearerTokenFormatIssue("   ") == nil)
  }
}
