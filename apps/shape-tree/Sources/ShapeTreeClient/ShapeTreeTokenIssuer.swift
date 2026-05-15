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

  // MARK: - JWTKit path (used by tests with JWTKit keys)

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

  // MARK: - Signing-closure path (used by apps with native CryptoKit keys)

  /// Mints an ES256 JWT whose signing input is signed by `sign`.
  ///
  /// The caller is responsible for providing the correct `kid` (RFC 7638
  /// thumbprint of the public key) and a `sign` closure that produces a raw
  /// P-256 ECDSA signature (`r || s`, 64 bytes) over the SHA-256 hash of the
  /// signing input.
  public static func mintES256(
    kid: String,
    deviceLabel: String? = nil,
    ttl: TimeInterval = 900,
    sign: (Data) throws -> Data
  ) throws -> String {
    let label = deviceLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let now = Int(Date().timeIntervalSince1970)

    var headerFields: [String: String] = [
      "typ": "JWT",
      "alg": "ES256",
      "kid": kid,
    ]
    if !label.isEmpty {
      headerFields["dev"] = label
    }

    let payloadFields: [String: Any] = [
      "sub": kid,
      "iat": now,
      "exp": now + Int(ttl),
      "jti": UUID().uuidString,
    ]

    let headerJSON = try JSONSerialization.data(withJSONObject: headerFields, options: [.sortedKeys])
    let payloadJSON = try JSONSerialization.data(withJSONObject: payloadFields, options: [.sortedKeys])

    let h = headerJSON.base64URLEncodedStringNoPadding()
    let p = payloadJSON.base64URLEncodedStringNoPadding()
    let signingInput = Data("\(h).\(p)".utf8)
    let signature = try sign(signingInput)
    let s = signature.base64URLEncodedStringNoPadding()
    return "\(h).\(p).\(s)"
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
