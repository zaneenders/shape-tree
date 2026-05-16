import Crypto
import Foundation
import HTTPTypes
import JWTKit
import ShapeTreeClient

@testable import ShapeTree

/// ES256 trust-store fixture for router/client integration tests (auth.md).
///
/// Each test gets its own ephemeral `authorized_keys/` directory with a single
/// freshly-minted P-256 key dropped in as `<thumbprint>.jwk`. The matching
/// private key stays in-process for minting test JWTs.
enum JWTTestSupport {

  /// Bundle of (private key for signing, store the middleware reads) usable
  /// from a single test.
  struct Fixture {
    let privateKey: ECDSA.PrivateKey<P256>
    let store: AuthorizedKeysStore
    let kid: String
    let directory: URL
  }

  /// Provisions a fresh trust store rooted in an ephemeral temp directory.
  static func makeFixture(label: String = "test-device") async throws -> Fixture {
    let key = ECDSA.PrivateKey<P256>()
    let coords = try ecCoords(of: key.publicKey)
    let kid = JWKThumbprint.thumbprint(crv: "P-256", x: coords.x, y: coords.y)

    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("shape-tree-tests-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("authorized_keys", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let jwk: [String: String] = [
      "kty": "EC",
      "crv": "P-256",
      "x": coords.x,
      "y": coords.y,
      "alg": "ES256",
      "use": "sig",
      "kid": kid,
      "label": label,
    ]
    let data = try JSONSerialization.data(withJSONObject: jwk, options: [.sortedKeys])
    let file = dir.appendingPathComponent("\(kid).jwk", isDirectory: false)
    try data.write(to: file, options: [.atomic])

    return Fixture(
      privateKey: key,
      store: AuthorizedKeysStore(directory: dir),
      kid: kid,
      directory: dir
    )
  }

  /// Minted bearer headers using the fixture's private key.
  static func bearerHeaders(_ fixture: Fixture, label: String = "test-device") throws -> HTTPFields {
    let token = try ShapeTreeTokenIssuer.mintES256(privateKey: fixture.privateKey, deviceLabel: label)
    return [.authorization: "Bearer \(token)"]
  }

  static func mintToken(_ fixture: Fixture, label: String = "test-device") throws -> String {
    try ShapeTreeTokenIssuer.mintES256(privateKey: fixture.privateKey, deviceLabel: label)
  }

  // MARK: - Helpers

  private struct Coords {
    let x: String
    let y: String
  }

  private static func ecCoords(of publicKey: ECDSA.PublicKey<P256>) throws -> Coords {
    guard let params = publicKey.parameters else {
      throw NSError(domain: "JWTTestSupport", code: 1)
    }
    guard let xRaw = Data.jwkCoordinateBytes(from: params.x),
      let yRaw = Data.jwkCoordinateBytes(from: params.y)
    else {
      throw NSError(domain: "JWTTestSupport", code: 1)
    }
    return Coords(
      x: xRaw.base64URLEncodedStringNoPadding(),
      y: yRaw.base64URLEncodedStringNoPadding()
    )
  }
}
