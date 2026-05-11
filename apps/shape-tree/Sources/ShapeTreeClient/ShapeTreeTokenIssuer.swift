import Crypto
import Foundation
import JWTKit

/// Mints ES256 JWTs against the SSH-`authorized_keys`-style trust store
/// (auth.md, "JWT shape").
///
/// Lives in ``ShapeTreeClient`` because every frontend (CLI, iOS app, macOS
/// app) needs to sign tokens with its on-device private key, and the test
/// suite of the server target re-uses the same helper for fixture tokens.
public enum ShapeTreeTokenIssuer {

  public static func mintES256(
    privateKey: ECDSA.PrivateKey<P256>,
    deviceLabel: String? = nil,
    ttl: TimeInterval = 900
  ) async throws -> String {
    guard let params = privateKey.parameters else {
      throw ShapeTreeTokenIssuerError.unableToReadPublicCoordinates
    }

    // JWTKit hands back standard-base64 x/y; the JWK and the thumbprint live
    // in base64url, so re-encode here.
    let xRaw = Data(base64Encoded: params.x) ?? Data()
    let yRaw = Data(base64Encoded: params.y) ?? Data()
    let xB64URL = xRaw.base64URLEncodedStringNoPadding()
    let yB64URL = yRaw.base64URLEncodedStringNoPadding()
    let kid = JWKThumbprint.thumbprint(crv: "P-256", x: xB64URL, y: yB64URL)

    let now = Date()
    let payload = ShapeTreeAuthJWTPayload(
      sub: SubjectClaim(value: kid),
      iat: IssuedAtClaim(value: now),
      exp: ExpirationClaim(value: now.addingTimeInterval(ttl)),
      jti: IDClaim(value: UUID().uuidString)
    )

    let keys = JWTKeyCollection()
    await keys.add(ecdsa: privateKey)

    var header: JWTHeader = ["typ": "JWT", "alg": "ES256", "kid": .string(kid)]
    if let label = deviceLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
      header.fields["dev"] = .string(label)
    }

    return try await keys.sign(payload, header: header)
  }
}

public enum ShapeTreeTokenIssuerError: Error, Equatable, Sendable {
  case unableToReadPublicCoordinates
}

/// Lightweight payload type used by ``ShapeTreeTokenIssuer`` for signing.
///
/// Mirrors the server's `ShapeTreeJWTPayload` claim set; kept as a separate
/// type so the public client SDK doesn't depend on the server target.
public struct ShapeTreeAuthJWTPayload: JWTPayload {
  public var sub: SubjectClaim
  public var iat: IssuedAtClaim
  public var exp: ExpirationClaim
  public var jti: IDClaim?

  public init(
    sub: SubjectClaim,
    iat: IssuedAtClaim,
    exp: ExpirationClaim,
    jti: IDClaim? = nil
  ) {
    self.sub = sub
    self.iat = iat
    self.exp = exp
    self.jti = jti
  }

  public func verify(using _: some JWTAlgorithm) throws {
    try exp.verifyNotExpired()
  }
}
