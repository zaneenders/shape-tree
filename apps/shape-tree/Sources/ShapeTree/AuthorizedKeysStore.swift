import Crypto
import Foundation
import JWTKit
import Logging
import ShapeTreeClient

struct AuthorizedKeysStore: Sendable {

  struct StoredKey: Sendable {
    let publicKey: ECDSA.PublicKey<P256>
    let thumbprint: String
    let label: String?
  }

  enum LookupError: Error, Sendable {
    case invalidKidShape
    case missing
    case symlink
    case malformed(String)
    case filenameMismatch(expected: String, fromFile: String)
  }

  let directory: URL

  init(directory: URL) {
    self.directory = directory.standardizedFileURL
  }

  func load(kid: String) throws -> StoredKey {
    guard JWKThumbprint.isWellFormed(kid) else {
      throw LookupError.invalidKidShape
    }

    let url = directory.appendingPathComponent("\(kid).jwk", isDirectory: false)

    let attrs: [FileAttributeKey: Any]
    do {
      attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    } catch {
      throw LookupError.missing
    }

    if let type = attrs[.type] as? FileAttributeType {
      if type == .typeSymbolicLink { throw LookupError.symlink }
      if type != .typeRegular { throw LookupError.missing }
    }

    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw LookupError.missing
    }

    let jwk: JWKFile
    do {
      jwk = try JSONDecoder().decode(JWKFile.self, from: data)
    } catch {
      throw LookupError.malformed("JSON decode failed: \(error.localizedDescription)")
    }

    if jwk.kty != "EC" {
      throw LookupError.malformed("kty must be \"EC\", got \"\(jwk.kty)\"")
    }
    if jwk.crv != "P-256" {
      throw LookupError.malformed("crv must be \"P-256\", got \"\(jwk.crv)\"")
    }
    if jwk.d != nil {
      throw LookupError.malformed("authorized_keys entry must not contain a private \"d\" parameter")
    }

    let publicKey: ECDSA.PublicKey<P256>
    do {
      publicKey = try ECDSA.PublicKey<P256>(parameters: (x: jwk.x, y: jwk.y))
    } catch {
      throw LookupError.malformed("invalid P-256 (x, y): \(error.localizedDescription)")
    }

    let recomputed = JWKThumbprint.thumbprint(crv: "P-256", x: jwk.x, y: jwk.y)
    if recomputed != kid {
      throw LookupError.filenameMismatch(expected: kid, fromFile: recomputed)
    }

    return StoredKey(publicKey: publicKey, thumbprint: recomputed, label: jwk.label)
  }
}

/// Minimal on-disk JWK schema we accept inside `authorized_keys/`.
///
/// Only the four RFC 7638 thumbprint fields participate in identity; `label`
/// is a non-standard convenience field that the operator can use to map a
/// `kid` back to a device when running `rm` (auth.md, "Revocation").
private struct JWKFile: Decodable {
  let kty: String
  let crv: String
  let x: String
  let y: String
  let d: String?
  let label: String?
  let kid: String?
}
