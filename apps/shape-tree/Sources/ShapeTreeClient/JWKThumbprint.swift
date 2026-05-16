import Crypto
import Foundation

public enum JWKThumbprint {

  /// Regex shape for a P-256 JWK thumbprint: 43 base64url chars (`[A-Za-z0-9_-]`), no padding.
  ///
  /// The middleware rejects `kid` values that don't match this *before* touching the
  /// filesystem so a malformed `kid` can never become a path-traversal vector.
  public static let regex = #"^[A-Za-z0-9_-]{43}$"#

  /// Returns true when `value` matches the canonical P-256 thumbprint shape.
  public static func isWellFormed(_ value: String) -> Bool {
    guard value.count == 43 else { return false }
    for ch in value.unicodeScalars {
      switch ch {
      case "A"..."Z", "a"..."z", "0"..."9", "-", "_": continue
      default: return false
      }
    }
    return true
  }

  /// RFC 7638 thumbprint of an EC P-256 JWK with already-base64url-encoded `x` and `y`.
  ///
  /// The JSON canonicalization is hand-built (no `JSONEncoder`) to guarantee
  /// byte-for-byte stability across platforms and Swift versions.
  public static func thumbprint(crv: String = "P-256", x: String, y: String) -> String {
    let json = #"{"crv":"\#(crv)","kty":"EC","x":"\#(x)","y":"\#(y)"}"#
    let digest = SHA256.hash(data: Data(json.utf8))
    return Data(digest).base64URLEncodedStringNoPadding()
  }

  /// Thumbprint of a raw uncompressed P-256 public key (`0x04 || x || y`, 65 bytes).
  ///
  /// Used by the iOS / macOS apps where the Security framework hands us the
  /// uncompressed point representation.
  public static func thumbprint(rawP256PublicKey raw: Data) throws -> String {
    guard raw.count == 65, raw.first == 0x04 else {
      throw JWKThumbprintError.invalidRawKey
    }
    let xBytes = raw.subdata(in: 1..<33)
    let yBytes = raw.subdata(in: 33..<65)
    return thumbprint(
      x: xBytes.base64URLEncodedStringNoPadding(),
      y: yBytes.base64URLEncodedStringNoPadding()
    )
  }
}

public enum JWKThumbprintError: Error, Equatable, Sendable {
  case invalidRawKey
}

// MARK: - base64url helpers

extension Data {
  /// base64url with no padding, per RFC 4648 §5.
  public func base64URLEncodedStringNoPadding() -> String {
    var s = self.base64EncodedString()
    s = s.replacingOccurrences(of: "+", with: "-")
    s = s.replacingOccurrences(of: "/", with: "_")
    while s.hasSuffix("=") { s.removeLast() }
    return s
  }

  /// Decodes base64url (with or without padding) back into raw bytes; returns nil on malformed input.
  public static func fromBase64URLNoPadding(_ string: String) -> Data? {
    var s = string
    s = s.replacingOccurrences(of: "-", with: "+")
    s = s.replacingOccurrences(of: "_", with: "/")
    let pad = (4 - s.count % 4) % 4
    s.append(String(repeating: "=", count: pad))
    return Data(base64Encoded: s)
  }

  /// Decodes a JWK EC `x`/`y` string: **base64url** first (RFC 7518), then standard base64 (some JWTKit paths).
  public static func jwkCoordinateBytes(from string: String) -> Data? {
    if let d = Data.fromBase64URLNoPadding(string), !d.isEmpty { return d }
    if let d = Data(base64Encoded: string), !d.isEmpty { return d }
    return nil
  }
}
