import Foundation
import JWTKit

/// Test-only helper and minting entry point that mirrors the server verifier (`HS256`, default claims).
enum ShapeTreeTokenIssuer {

  static func mintHS256(secret: String, subject: String = "shape-tree") async throws -> String {
    let keys = JWTKeyCollection()
    await keys.add(hmac: HMACKey(from: secret), digestAlgorithm: .sha256)

    let payload = ShapeTreeJWTPayload(
      sub: SubjectClaim(value: subject),
      iat: IssuedAtClaim(value: Date()),
      exp: ExpirationClaim(value: Date().addingTimeInterval(3600))
    )

    return try await keys.sign(payload)
  }
}
