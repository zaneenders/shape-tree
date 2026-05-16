import Crypto
import Foundation
import JWTKit

/// ES256 JWT minting for the `authorized_keys` trust model. Claims must match ``ShapeTreeJWTPayload``.
public enum ShapeTreeTokenIssuer {

  /// JWTKit private key path for tests/tooling (PEM round-trip to CryptoKit).
  public static func mintES256(
    privateKey: ECDSA.PrivateKey<P256>,
    deviceLabel: String? = nil,
    ttl: TimeInterval = 900
  ) throws -> String {
    guard let params = privateKey.parameters else {
      throw ShapeTreeTokenIssuerError.unableToReadPublicCoordinates
    }

    guard let xRaw = Data.jwkCoordinateBytes(from: params.x),
      let yRaw = Data.jwkCoordinateBytes(from: params.y)
    else {
      throw ShapeTreeTokenIssuerError.unableToReadPublicCoordinates
    }

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

  /// Canonical mint: sorted JSON header/payload, base64url, ES256 over signing input. Caller supplies `kid` + `sign`.
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
