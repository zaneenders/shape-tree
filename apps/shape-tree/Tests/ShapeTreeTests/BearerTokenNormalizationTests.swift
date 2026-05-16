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
    // Simulates terminal word-wrap: a JWT split across lines by the terminal.
    let wrapped = """
      eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3NzgzNTQ1ODMuMDQzNDgzLCJzdWIiOiJzaGFwZS10
      cmVlLUFEN0JCN0Y3LUNDMzItNEM1Mi04ODA2LTIxQjRDOUFFNDc5QSIsImlhdCI6MTc3OD
      MzNTA5ODMuMDQzNDgzfQ.fpysfjm1T4gcy7HEpbkkrQpICf1B0hnVQN4xzF-qMjU
      """
    let normalized = ShapeTreeAPIClientMiddleware.normalizedBearerJWT(wrapped)
    #expect(!normalized.contains { $0.isWhitespace || $0.isNewline })
    #expect(normalized.components(separatedBy: ".").count == 3)
  }
}
