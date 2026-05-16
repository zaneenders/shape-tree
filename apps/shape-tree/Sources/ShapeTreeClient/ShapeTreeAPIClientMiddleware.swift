import OpenAPIRuntime

public enum ShapeTreeAPIClientMiddleware {

  /// Returns the raw JWT suitable for `Authorization: Bearer …`.
  ///
  /// Handles common pastes: `eyJ…`, `Bearer eyJ…`, `Bearer Bearer eyJ…`, or
  /// `Authorization: Bearer eyJ…`. Also removes any embedded whitespace/newlines
  /// (e.g. terminal word-wrap) since a valid JWT is base64url + dots only.
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

    return s.filter { !$0.isWhitespace && !$0.isNewline }
  }
}
