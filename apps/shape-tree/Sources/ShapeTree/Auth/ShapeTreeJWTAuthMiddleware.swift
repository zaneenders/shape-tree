import Foundation
import HTTPTypes
import Hummingbird
import JWTKit
import ShapeTreeClient

/// Bearer JWT auth: ES256 only, outer parse pins alg/typ/kid before disk;
/// single-key verify via ``AuthorizedKeysStore`` (thumbprint must match filename).
/// Enforces `iat` skew window, mandatory `jti`, and ``JWTReplayCache`` replay defense.
struct ShapeTreeJWTAuthMiddleware: MiddlewareProtocol {
  typealias Input = Request
  typealias Output = Response
  typealias Context = BasicRequestContext

  static let maxIATBackdate: TimeInterval = 30 * 60

  static let maxIATSkewFuture: TimeInterval = 60

  private let store: AuthorizedKeysStore
  private let replayCache: JWTReplayCache

  init(store: AuthorizedKeysStore, replayCache: JWTReplayCache) {
    self.store = store
    self.replayCache = replayCache
  }

  func handle(
    _ request: Input,
    context: Context,
    next: @concurrent (Input, Context) async throws -> Output
  ) async throws -> Output {
    context.logger.debug(
      "event=http.request method=\(request.method) path=\(request.head.path ?? "")")

    let token = try Self.extractBearerToken(from: request)
    let outer = try Self.validateOuterHeader(token: token)

    let stored: AuthorizedKeysStore.StoredKey
    do {
      stored = try store.load(kid: outer.kid)
    } catch {
      context.logger.warning("event=auth.lookup_rejected kid=\(outer.kid) error=\(error)")
      throw HTTPError(.unauthorized, message: "Unknown or invalid kid")
    }

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

    guard payload.sub.value == outer.kid else {
      context.logger.warning("event=auth.sub_mismatch kid=\(outer.kid) sub=\(payload.sub.value)")
      throw HTTPError(.unauthorized, message: "Invalid or expired JWT")
    }

    let now = Date()
    let iat = payload.iat.value
    if iat < now.addingTimeInterval(-Self.maxIATBackdate) {
      context.logger.warning(
        "event=auth.iat_too_old kid=\(outer.kid) iat=\(iat.timeIntervalSince1970)")
      throw HTTPError(.unauthorized, message: "Token iat outside accepted skew window")
    }
    if iat > now.addingTimeInterval(Self.maxIATSkewFuture) {
      context.logger.warning(
        "event=auth.iat_in_future kid=\(outer.kid) iat=\(iat.timeIntervalSince1970)")
      throw HTTPError(.unauthorized, message: "Token iat outside accepted skew window")
    }

    guard let jti = payload.jti?.value, !jti.isEmpty else {
      context.logger.warning("event=auth.missing_jti kid=\(outer.kid)")
      throw HTTPError(.unauthorized, message: "Token missing jti")
    }

    let admission: JWTReplayCache.Decision
    do {
      admission = try await replayCache.admit(
        kid: outer.kid, jti: jti, exp: payload.exp.value, now: now)
    } catch JWTReplayCache.AdmissionError.capacityExceeded {
      context.logger.error("event=auth.replay_cache_full kid=\(outer.kid)")
      throw HTTPError(.serviceUnavailable, message: "Auth cache saturated; retry shortly")
    }
    if case .replay = admission {
      context.logger.warning("event=auth.replay kid=\(outer.kid) jti=\(jti)")
      throw HTTPError(.unauthorized, message: "Token already used")
    }

    context.logger.info(
      "event=auth.ok kid=\(stored.thumbprint) sub=\(payload.sub.value) dev=\(outer.dev.isEmpty ? "-" : outer.dev)")

    return try await next(request, context)
  }

  private static func extractBearerToken(from request: Request) throws -> String {
    guard let authHeader = request.headers[.authorization] else {
      throw HTTPError(.unauthorized, message: "Missing Authorization header")
    }
    guard authHeader.hasPrefix("Bearer ") else {
      throw HTTPError(.unauthorized, message: "Invalid Authorization header format")
    }
    return String(authHeader.dropFirst(7))
  }

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

private struct UnverifiedJWTPayload: JWTPayload {
  func verify(using _: some JWTAlgorithm) throws {}
}
