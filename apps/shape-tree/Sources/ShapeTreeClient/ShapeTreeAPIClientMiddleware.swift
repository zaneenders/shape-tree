import JWTKit
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

  public static func bearerJWT(_ token: String?) -> [any ClientMiddleware] {
    let trimmed = token.map { normalizedBearerJWT($0) } ?? ""
    guard !trimmed.isEmpty else { return [] }
    return [BearerAuthClientMiddleware(bearerToken: trimmed)]
  }

  // MARK: - Token format validation (uses JWTKit for proper JWT structure parsing)

  /// If non-empty `raw` cannot plausibly be a JWT string, returns guidance for the Connection sheet.
  ///
  /// Uses JWTKit's `unverified` parser to validate JWT structure (header, payload, signature segments,
  /// base64url encoding, JSON body) without verifying the cryptographic signature—that's the server's job.
  public static func bearerTokenFormatIssue(_ raw: String) -> String? {
    let t = normalizedBearerJWT(raw)
    guard !t.isEmpty else { return nil }

    let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)

    // Quick heuristic: the user pasted the config file or the secret itself.
    if trimmed.first == "{"
      || trimmed.range(of: "\"secret\"", options: .caseInsensitive) != nil
      || trimmed.range(of: "\"jwt\"", options: .caseInsensitive) != nil
    {
      return """
        That looks like JSON or a config snippet—not a JWT. The server's jwt.secret stays in shape-tree-config.json only. \
        Here paste a signed token (three segments like eyJ… . … . …), minted with the same HS256 setup as this server (JWTKit + swift-crypto).
        """
    }

    // Use JWTKit's parser to validate the token structure (3 segments, valid base64url,
    // well-formed JSON header and payload). This replaces manual dot-counting with proper JWT parsing.
    do {
      let parser = DefaultJWTParser()
      _ = try parser.parse([UInt8](trimmed.utf8), as: PlaceholderJWTPayload.self)
    } catch let error as JWTError {
      return jwtKitErrorMessage(error)
    } catch {
      return "The JWT couldn't be parsed: \(error.localizedDescription)"
    }

    return nil
  }

  private static func jwtKitErrorMessage(_ error: JWTError) -> String {
    switch error.errorType {
    case .malformedToken:
      return """
        That doesn't look like a valid JWT: \(error.localizedDescription) \
        A JWT has three dot-separated base64url segments (header.payload.signature). \
        If you pasted jwt.secret from config, that value signs tokens but is not a token itself—mint a JWT first \
        (see apps/shape-tree README).
        """
    default:
      return "The JWT couldn't be parsed: \(error.localizedDescription)"
    }
  }
}

// MARK: - Minimal payload for client-side structure validation

/// A zero-field `JWTPayload` used solely to drive JWTKit's `unverified` parser.
/// The parser validates segment count, base64url encoding, and JSON structure without
/// needing to know the server's claim set (sub, iat, exp, jti, etc.).
struct PlaceholderJWTPayload: JWTPayload {
  func verify(using _: some JWTAlgorithm) throws {}
}
