import HTTPTypes
@testable import ShapeTree
import JWTKit

enum JWTTestSupport {
  /// Shared secret for router/client integration tests (`HS256`).
  static let secret = "shape-tree-router-tests-jwt-secret-key"

  static func makeVerifierKeys() async -> JWTKeyCollection {
    let jwtKeys = JWTKeyCollection()
    await jwtKeys.add(hmac: HMACKey(from: secret), digestAlgorithm: .sha256)
    return jwtKeys
  }

  static func bearerHeaders() async throws -> HTTPFields {
    let token = try await ShapeTreeTokenIssuer.mintHS256(secret: secret)
    return [.authorization: "Bearer \(token)"]
  }
}
