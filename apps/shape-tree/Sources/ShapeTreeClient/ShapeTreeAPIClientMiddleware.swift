import OpenAPIRuntime

/// Builds middleware stacks for apps that link only `ShapeTreeClient`.
public enum ShapeTreeAPIClientMiddleware {

  /// Returns the raw JWT suitable for `Authorization: Bearer …`.
  ///
  /// Handles common pastes: `eyJ…`, `Bearer eyJ…`, `Bearer Bearer eyJ…`, or `Authorization: Bearer eyJ…`.
  public static func normalizedBearerJWT(_ raw: String) -> String {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return "" }

    let authSchemePrefix = "authorization:"
    if s.lowercased().hasPrefix(authSchemePrefix) {
      s = String(s.dropFirst(authSchemePrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    while s.lowercased().hasPrefix("bearer ") {
      s = String(s.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return s
  }

  public static func bearerJWT(_ token: String?) -> [any ClientMiddleware] {
    let trimmed = token.map { normalizedBearerJWT($0) } ?? ""
    guard !trimmed.isEmpty else { return [] }
    return [BearerAuthClientMiddleware(bearerToken: trimmed)]
  }

  /// If non-empty `raw` cannot plausibly be a JWT string, returns guidance for the Connection sheet.
  public static func bearerTokenFormatIssue(_ raw: String) -> String? {
    let t = normalizedBearerJWT(raw)
    guard !t.isEmpty else { return nil }

    let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.first == "{"
      || trimmed.range(of: "\"secret\"", options: .caseInsensitive) != nil
      || trimmed.range(of: "\"jwt\"", options: .caseInsensitive) != nil
    {
      return """
      That looks like JSON or a config snippet—not a JWT. The server's jwt.secret stays in shape-tree-config.json only. \
      Here paste a signed token (three segments like eyJ… . … . …), minted with the same HS256 setup as this server (JWTKit + swift-crypto).
      """
    }

    let parts = trimmed.components(separatedBy: ".")
    if parts.count != 3 || parts.contains(where: \.isEmpty) {
      return """
      A JWT has exactly three dot-separated segments. If you pasted jwt.secret from config, that value signs tokens but is not a token itself—mint a JWT first (see apps/shape-tree README).
      """
    }

    return nil
  }
}
