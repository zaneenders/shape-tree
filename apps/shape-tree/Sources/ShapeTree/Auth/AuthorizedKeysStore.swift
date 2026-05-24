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

  /// Cheap on-disk identity for cache revalidation (`contentModificationDate` + size).
  struct FileStamp: Sendable, Equatable {
    let contentModificationDate: Date?
    let fileSize: Int?
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

  /// Stat the JWK for `kid` without reading or parsing file contents.
  func fileStamp(kid: String) throws -> FileStamp {
    let (_, resourceValues) = try jwkResourceValues(kid: kid)
    return FileStamp(
      contentModificationDate: resourceValues.contentModificationDate,
      fileSize: resourceValues.fileSize
    )
  }

  func load(kid: String) throws -> StoredKey {
    let (url, _) = try jwkResourceValues(kid: kid)

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

  private func jwkResourceValues(kid: String) throws -> (URL, URLResourceValues) {
    guard JWKThumbprint.isWellFormed(kid) else {
      throw LookupError.invalidKidShape
    }

    let url = directory.appendingPathComponent("\(kid).jwk", isDirectory: false)

    let resourceValues: URLResourceValues
    do {
      resourceValues = try url.resourceValues(forKeys: [
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .contentModificationDateKey,
        .fileSizeKey,
      ])
    } catch {
      throw LookupError.missing
    }
    if resourceValues.isSymbolicLink == true { throw LookupError.symlink }
    guard resourceValues.isRegularFile == true else { throw LookupError.missing }

    return (url, resourceValues)
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

/// On-disk JWK in `authorized_keys/`. Identity comes from thumbprint fields; `label` is optional metadata.
private struct JWKFile: Decodable {
  let kty: String
  let crv: String
  let x: String
  let y: String
  let d: String?
  let label: String?
}
