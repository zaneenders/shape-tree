import Crypto
import Foundation
import JWTKit
import Logging
import ShapeTreeClient

/// Reads `<thumbprint>.jwk` files out of `R/.shape-tree/authorized_keys/` (auth.md, "Server layout").
///
/// The store is read-only with respect to the trust store; the daemon never
/// creates, renames, or deletes files here. Per-request lookups stat + read
/// the keyfile, so revocation is `rm <kid>.jwk` with no extra plumbing
/// (auth.md, "Propagation knobs", option 2).
struct AuthorizedKeysStore: Sendable {

  /// Validated public key + bookkeeping fields the middleware needs after a successful lookup.
  struct StoredKey: Sendable {
    let publicKey: ECDSA.PublicKey<P256>
    /// RFC 7638 thumbprint computed by re-canonicalizing the on-disk JWK.
    let thumbprint: String
    /// Optional `label` from the JWK (operator-friendly device name); never used for authorization.
    let label: String?
  }

  enum LookupError: Error, Sendable {
    /// `kid` did not match the strict thumbprint regex; filesystem was not touched.
    case invalidKidShape
    /// `<kid>.jwk` does not exist or is not a regular file (revoked, never enrolled, or wrong type).
    case missing
    /// Symlink encountered — we never follow them inside `authorized_keys/`.
    case symlink
    /// JWK contents wouldn't parse as a P-256 public key, or contained `d`.
    case malformed(String)
    /// Recomputed thumbprint did not match the filename basename — operator error / partial tamper.
    case filenameMismatch(expected: String, fromFile: String)
  }

  let directory: URL

  init(directory: URL) {
    self.directory = directory.standardizedFileURL
  }

  /// Loads the keyfile for `kid`, runs RFC 7638 / file-integrity checks, and returns a verified
  /// public key. Filesystem is **not** touched if `kid` doesn't match the thumbprint regex.
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
      data = try Data(contentsOf: url, options: [.uncached])
    } catch {
      throw LookupError.missing
    }

    let parsed: JWKFile
    do {
      parsed = try JSONDecoder().decode(JWKFile.self, from: data)
    } catch {
      throw LookupError.malformed("JSON decode failed: \(error.localizedDescription)")
    }

    if parsed.kty != "EC" {
      throw LookupError.malformed("kty must be \"EC\", got \"\(parsed.kty)\"")
    }
    if parsed.crv != "P-256" {
      throw LookupError.malformed("crv must be \"P-256\", got \"\(parsed.crv)\"")
    }
    if parsed.d != nil {
      throw LookupError.malformed("authorized_keys entry must not contain a private \"d\" parameter")
    }

    let publicKey: ECDSA.PublicKey<P256>
    do {
      publicKey = try ECDSA.PublicKey<P256>(parameters: (x: parsed.x, y: parsed.y))
    } catch {
      throw LookupError.malformed("invalid P-256 (x, y): \(error.localizedDescription)")
    }

    let recomputed = JWKThumbprint.thumbprint(crv: "P-256", x: parsed.x, y: parsed.y)
    if recomputed != kid {
      throw LookupError.filenameMismatch(expected: kid, fromFile: recomputed)
    }

    return StoredKey(publicKey: publicKey, thumbprint: recomputed, label: parsed.label)
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
