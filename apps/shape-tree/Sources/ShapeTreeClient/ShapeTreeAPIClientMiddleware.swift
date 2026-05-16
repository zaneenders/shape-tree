import OpenAPIRuntime

/// Builds middleware stacks for apps that link only `ShapeTreeClient`.
public enum ShapeTreeAPIClientMiddleware {

  // MARK: - Bearer token normalization

  /// Returns the raw JWT suitable for `Authorization: Bearer …`.
  ///
  /// Handles common pastes: `eyJ…`, `Bearer eyJ…`, `Bearer Bearer eyJ…`, or `Authorization: Bearer eyJ…`.
  /// Also removes any embedded whitespace/newlines (e.g. from terminal word-wrap) since a valid JWT
  /// contains only base64url characters and dots.
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

    // Remove any embedded whitespace/newlines (terminal word-wrap, stray spaces).
    // A JWT is always base64url + dots — no whitespace is ever valid inside one.
    s = s.filter { !$0.isWhitespace && !$0.isNewline }

    return s
  }

  /// Wraps a static bearer JWT for generated ``Client`` stacks (typically integration tests).
  public static func bearerJWT(_ token: String?) -> [any ClientMiddleware] {
    let trimmed = token.map { normalizedBearerJWT($0) } ?? ""
    guard !trimmed.isEmpty else { return [] }
    return [BearerAuthClientMiddleware(bearerToken: trimmed)]
  }
}
