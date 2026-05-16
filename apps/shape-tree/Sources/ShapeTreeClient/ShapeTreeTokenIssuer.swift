import Crypto
import Foundation
import JWTKit

/// ES256 JWT minting for the SSH-style `authorized_keys` trust model (see `.dev/auth.md`).
///
/// **`mintES256(kid:deviceLabel:ttl:sign:)`** is the canonical JWS compose path — fixed header/payload JSON
/// (sorted keys), base64url segments, ES256 SHA-256-over-signing-input as implemented by CryptoKit's
/// `P256.Signing.PrivateKey.signature(for:)`.
///
/// - **Apps (Secure Enclave / CryptoKit)** — ``ShapeTreeKeyStore/mintES256JWT(ttl:)`` supplies `kid` and a closure
///   over CryptoKit-held keys.
/// - **Tests / tooling with JWTKit keys** — ``mintES256(privateKey:deviceLabel:ttl:)`` bridges the JWTKit wrapper to
///   CryptoKit via PEM so it delegates to the same compose + sign pipeline.
///
/// The server verifies using ``ShapeTreeJWTPayload``; keep claim fields aligned with that type only.
public enum ShapeTreeTokenIssuer {

  /// Signs with a JWTKit `ECDSA.PrivateKey` (fixtures / tooling). PEM-round-trips into CryptoKit so signatures match
  /// device minting and server verification.
  public static func mintES256(
    privateKey: ECDSA.PrivateKey<P256>,
    deviceLabel: String? = nil,
    ttl: TimeInterval = 900
  ) throws -> String {
    guard let params = privateKey.parameters else {
      throw ShapeTreeTokenIssuerError.unableToReadPublicCoordinates
    }

    let xRaw = Data(base64Encoded: params.x) ?? Data()
    let yRaw = Data(base64Encoded: params.y) ?? Data()
    let xB64URL = xRaw.base64URLEncodedStringNoPadding()
    let yB64URL = yRaw.base64URLEncodedStringNoPadding()
    let kid = JWKThumbprint.thumbprint(crv: "P-256", x: xB64URL, y: yB64URL)

    let signingKey = try P256.Signing.PrivateKey(pemRepresentation: privateKey.pemRepresentation)
    return try mintES256(
      kid: kid,
      deviceLabel: deviceLabel,
      ttl: ttl,
      sign: { data in try signingKey.signature(for: data).rawRepresentation }
    )
  }

  /// Builds a compact JWS and signs `header.payload` UTF-8 (ES256 — SHA-256 digest of the signing input, then ECDSA).
  ///
  /// The caller supplies RFC 7638 `kid`; ``ShapeTreeKeyStore`` wires Secure Enclave / software keys as the typical
  /// closure implementation.
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
