import Crypto
import Foundation
import JWTKit
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

    let resourceValues: URLResourceValues
    do {
      resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    } catch {
      throw LookupError.missing
    }
    if resourceValues.isSymbolicLink == true { throw LookupError.symlink }
    guard resourceValues.isRegularFile == true else { throw LookupError.missing }

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

    return try makeStoredKey(jwk: jwk, kid: kid)
  }

  private func makeStoredKey(jwk: JWKFile, kid: String) throws -> StoredKey {
    guard jwk.kty == "EC" else {
      throw LookupError.malformed("kty must be \"EC\", got \"\(jwk.kty)\"")
    }
    guard jwk.crv == "P-256" else {
      throw LookupError.malformed("crv must be \"P-256\", got \"\(jwk.crv)\"")
    }
    guard jwk.d == nil else {
      throw LookupError.malformed(
        "authorized_keys entry must not contain a private \"d\" parameter")
    }

    let publicKey: ECDSA.PublicKey<P256>
    do {
      publicKey = try ECDSA.PublicKey<P256>(parameters: (x: jwk.x, y: jwk.y))
    } catch {
      throw LookupError.malformed("invalid P-256 (x, y): \(error.localizedDescription)")
    }

    let thumbprint = JWKThumbprint.thumbprint(crv: "P-256", x: jwk.x, y: jwk.y)
    guard thumbprint == kid else {
      throw LookupError.filenameMismatch(expected: kid, fromFile: thumbprint)
    }

    return StoredKey(publicKey: publicKey, thumbprint: thumbprint, label: jwk.label)
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
}
