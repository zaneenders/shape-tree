import Foundation
import HTTPTypes
import Hummingbird
import JWTKit
import ShapeTreeClient

/// Validates `Authorization: Bearer <jwt>` against the SSH-`authorized_keys`-style
/// trust store described in `.dev/auth.md`.
///
/// The middleware is the *only* place that decides whether a request is
/// authenticated; everything else (handlers, openapi-generated stubs) trusts
/// that a request which reaches it has been verified.
///
/// Verification is ES256-only with a deliberate two-pin against the classic
/// JWT alg-confusion family (`alg: none`, HS/ES mix-ups, key-substitution):
///
/// 1. **Outer pin** — JWTKit's parser splits and JSON-decodes the token *without*
///    verifying the signature; we then **pin** `alg == "ES256"`, `typ == "JWT"`,
///    and `kid` shape *before* the filesystem is touched.
/// 2. **Inner pin** — build a single-key, ES256-only `JWTKeyCollection`
///    rooted at exactly the public key the (validated) `kid` points at, and
///    hand that to JWTKit. The key is registered with no algorithm metadata
///    from the JWK; the algorithm is fixed in code.
///
/// Step 5 in the auth.md flow — recompute the RFC 7638 thumbprint of the
/// loaded public key and require `thumbprint == kid == filename basename` —
/// is performed inside ``AuthorizedKeysStore`` (see `LookupError`).
struct ShapeTreeJWTAuthMiddleware: MiddlewareProtocol {
  typealias Input = Request
  typealias Output = Response
  typealias Context = BasicRequestContext

  private let store: AuthorizedKeysStore

  init(store: AuthorizedKeysStore) {
    self.store = store
  }

  func handle(
    _ request: Input,
    context: Context,
    next: @concurrent (Input, Context) async throws -> Output
  ) async throws -> Output {
    context.logger.debug(
      "event=http.request method=\(request.method) path=\(request.head.path ?? "")"
    )

    guard let authHeader = request.headers[.authorization] else {
      throw HTTPError(.unauthorized, message: "Missing Authorization header")
    }
    guard authHeader.hasPrefix("Bearer ") else {
      throw HTTPError(.unauthorized, message: "Invalid Authorization header format")
    }
    let token = String(authHeader.dropFirst(7))

    // ---- Outer pin: structural parse only — pins alg/typ/kid before disk or verify.

    let header: JWTHeader
    do {
      header = try DefaultJWTParser().parse([UInt8](token.utf8), as: UnverifiedJWTPayload.self).header
    } catch {
      context.logger.debug("JWT parse failed: \(String(describing: error))")
      throw HTTPError(.unauthorized, message: "Malformed JWT")
    }

    guard header.typ == "JWT" else {
      throw HTTPError(.unauthorized, message: "Unsupported JWT typ")
    }
    guard header.alg == "ES256" else {
      throw HTTPError(.unauthorized, message: "Unsupported JWT alg")
    }
    let kid = header.kid ?? ""
    guard JWKThumbprint.isWellFormed(kid) else {
      throw HTTPError(.unauthorized, message: "Invalid kid")
    }

    // ---- Authorized-keys lookup (filesystem touched only after the outer pin).

    let stored: AuthorizedKeysStore.StoredKey
    do {
      stored = try store.load(kid: kid)
    } catch let err as AuthorizedKeysStore.LookupError {
      switch err {
      case .filenameMismatch(let expected, let fromFile):
        context.logger.warning(
          "event=auth.trust_store_integrity kid=\(expected) recomputed=\(fromFile)"
        )
      case .symlink:
        context.logger.warning("event=auth.trust_store_symlink kid=\(kid)")
      case .malformed(let reason):
        context.logger.warning("event=auth.trust_store_malformed kid=\(kid) reason=\(reason)")
      case .missing, .invalidKidShape:
        break
      }
      throw HTTPError(.unauthorized, message: "Unknown or invalid kid")
    } catch {
      context.logger.debug("authorized_keys lookup failed: \(String(describing: error))")
      throw HTTPError(.unauthorized, message: "Unknown or invalid kid")
    }

    // ---- Inner pin: single-key, ES256-only verifier built fresh per request.

    let keys = JWTKeyCollection()
    await keys.add(ecdsa: stored.publicKey)

    let payload: ShapeTreeJWTPayload
    do {
      payload = try await keys.verify(token, as: ShapeTreeJWTPayload.self)
    } catch let jwtError as JWTError {
      if jwtError.errorType == JWTError.ErrorType.claimVerificationFailure,
        jwtError.failedClaim is ExpirationClaim
      {
        throw HTTPError(.unauthorized, message: "JWT token expired")
      }
      context.logger.debug("JWT verification failed: \(String(describing: jwtError))")
      throw HTTPError(.unauthorized, message: "Invalid or expired JWT")
    } catch {
      context.logger.debug("JWT verification failed: \(String(describing: error))")
      throw HTTPError(.unauthorized, message: "Invalid or expired JWT")
    }

    // ---- Bind sub to kid: the subject must be the RFC 7638 thumbprint of the
    //      key that signed this token. Since kid == filename == thumbprint
    //      (enforced by AuthorizedKeysStore), this prevents a token signed by
    //      one enrolled key from claiming the identity of a different key.
    guard payload.sub.value == kid else {
      context.logger.warning(
        "event=auth.sub_mismatch kid=\(kid) sub=\(payload.sub.value)"
      )
      throw HTTPError(.unauthorized, message: "Invalid or expired JWT")
    }

    let dev = header.fields["dev"]?.asString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    context.logger.info(
      "event=auth.ok kid=\(stored.thumbprint) sub=\(payload.sub.value) dev=\(dev.isEmpty ? "-" : dev)"
    )

    return try await next(request, context)
  }
}

/// Drives ``DefaultJWTParser`` for segment split + JSON decode without signature verification.
private struct UnverifiedJWTPayload: JWTPayload {
  func verify(using _: some JWTAlgorithm) throws {}
}
