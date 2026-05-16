import Crypto
import Foundation
import JWTKit

/// ES256 JWT minting for the SSH-style `authorized_keys` trust model (see `.dev/auth.md`).
///
/// **Which API to use**
///
/// - **Apps (Secure Enclave / CryptoKit)** — Call ``ShapeTreeKeyStore/mintES256JWT(ttl:)``, which wraps
///   ``mintES256(kid:deviceLabel:ttl:sign:)`` with the correct `kid` and a signing closure over the raw JWS input.
/// - **Tests / tooling with JWTKit keys** — Use ``mintES256(privateKey:deviceLabel:ttl:)``, which builds the same
///   header + payload shape via JWTKit's signer.
///
/// The server verifies tokens using the same ``ShapeTreeJWTPayload`` claim set and its authorized-keys middleware;
/// keep fields aligned with that type only.
public enum ShapeTreeTokenIssuer {

  // MARK: - JWTKit path

  /// Signs with a JWTKit-owned P-256 private key (typical for tests and headless fixtures).
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
    let payload = ShapeTreeJWTPayload(
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

  // MARK: - Signing-closure path (CryptoKit / Secure Enclave)

  /// Builds a JWS and signs the `header.payload` input with `sign` (raw P-256 ECDSA, `r || s`, 64 bytes).
  ///
  /// The caller supplies `kid` (thumbprint of the public key); ``ShapeTreeKeyStore`` is the typical entry point.
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
