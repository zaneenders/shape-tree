import Foundation
import HTTPTypes
import Hummingbird
import JWTKit
import ShapeTreeClient

/// Validates `Authorization: Bearer <jwt>` against the SSH-`authorized_keys`-style
/// trust store described in `.dev/auth.md`. The middleware is the *only* place that
/// decides whether a request is authenticated; everything else trusts that a request
/// which reaches it has been verified.
///
/// ES256-only with a deliberate two-pin against the alg-confusion family
/// (`alg: none`, HS/ES mix-ups, key-substitution):
///
/// 1. **Outer pin** — JWTKit's parser splits and JSON-decodes the token *without*
///    verifying the signature; we then pin `alg == "ES256"`, `typ == "JWT"`, and
///    `kid` shape *before* the filesystem is touched.
/// 2. **Inner pin** — build a single-key, ES256-only `JWTKeyCollection` rooted at
///    exactly the public key the (validated) `kid` points at, and hand that to JWTKit.
///
/// Step 5 in the auth.md flow — recompute the RFC 7638 thumbprint of the loaded public
/// key and require `thumbprint == kid == filename basename` — is enforced inside
/// ``AuthorizedKeysStore``.
struct ShapeTreeJWTAuthMiddleware: MiddlewareProtocol {
  typealias Input = Request
  typealias Output = Response
  typealias Context = BasicRequestContext

  private let store: AuthorizedKeysStore

  init(store: AuthorizedKeysStore) { self.store = store }

  func handle(
    _ request: Input,
    context: Context,
    next: @concurrent (Input, Context) async throws -> Output
  ) async throws -> Output {
    context.logger.debug(
      "event=http.request method=\(request.method) path=\(request.head.path ?? "")")

    let token = try Self.extractBearerToken(from: request)
    let outer = try Self.validateOuterHeader(token: token)

    // ---- Authorized-keys lookup (filesystem touched only after the outer pin).
    let stored: AuthorizedKeysStore.StoredKey
    do {
      stored = try store.load(kid: outer.kid)
    } catch {
      context.logger.warning("event=auth.lookup_rejected kid=\(outer.kid) error=\(error)")
      throw HTTPError(.unauthorized, message: "Unknown or invalid kid")
    }

    // ---- Inner pin: single-key, ES256-only verifier built fresh per request.
    let keys = JWTKeyCollection()
    await keys.add(ecdsa: stored.publicKey)

    let payload: ShapeTreeJWTPayload
    do {
      payload = try await keys.verify(token, as: ShapeTreeJWTPayload.self)
    } catch let jwtError as JWTError
      where jwtError.errorType == .claimVerificationFailure
        && jwtError.failedClaim is ExpirationClaim
    {
      throw HTTPError(.unauthorized, message: "JWT token expired")
    } catch {
      context.logger.debug("JWT verification failed: \(String(describing: error))")
      throw HTTPError(.unauthorized, message: "Invalid or expired JWT")
    }

    // ---- Bind sub to kid: prevents a token signed by one enrolled key from claiming
    //      the identity of a different key (kid == filename == thumbprint, enforced by
    //      AuthorizedKeysStore).
    guard payload.sub.value == outer.kid else {
      context.logger.warning("event=auth.sub_mismatch kid=\(outer.kid) sub=\(payload.sub.value)")
      throw HTTPError(.unauthorized, message: "Invalid or expired JWT")
    }

    context.logger.info(
      "event=auth.ok kid=\(stored.thumbprint) sub=\(payload.sub.value) dev=\(outer.dev.isEmpty ? "-" : outer.dev)")

    return try await next(request, context)
  }

  // MARK: - Internals

  private static func extractBearerToken(from request: Request) throws -> String {
    guard let authHeader = request.headers[.authorization] else {
      throw HTTPError(.unauthorized, message: "Missing Authorization header")
    }
    guard authHeader.hasPrefix("Bearer ") else {
      throw HTTPError(.unauthorized, message: "Invalid Authorization header format")
    }
    return String(authHeader.dropFirst(7))
  }

  /// Outer pin: structural parse only — pins alg/typ/kid before disk or signature verify.
  /// Returns the validated `kid` and the (untrusted, log-only) `dev` label.
  private static func validateOuterHeader(token: String) throws -> (kid: String, dev: String) {
    let header: JWTHeader
    do {
      header = try DefaultJWTParser().parse([UInt8](token.utf8), as: UnverifiedJWTPayload.self).header
    } catch {
      throw HTTPError(.unauthorized, message: "Malformed JWT")
    }

    guard header.typ == "JWT" else { throw HTTPError(.unauthorized, message: "Unsupported JWT typ") }
    guard header.alg == "ES256" else { throw HTTPError(.unauthorized, message: "Unsupported JWT alg") }

    let kid = header.kid ?? ""
    guard JWKThumbprint.isWellFormed(kid) else {
      throw HTTPError(.unauthorized, message: "Invalid kid")
    }

    let dev = header.fields["dev"]?.asString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (kid, dev)
  }
}

/// Drives ``DefaultJWTParser`` for segment split + JSON decode without signature verification.
private struct UnverifiedJWTPayload: JWTPayload {
  func verify(using _: some JWTAlgorithm) throws {}
}
