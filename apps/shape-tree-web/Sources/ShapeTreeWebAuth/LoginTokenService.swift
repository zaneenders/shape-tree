import Crypto
import Foundation

enum LoginTokenService {
  static func generate() -> (raw: String, hash: String) {
    let key = SymmetricKey(size: .bits256)
    let raw = base64URLEncode(key.withUnsafeBytes { Data($0) })
    let hash = sha256Hex(raw)
    return (raw, hash)
  }

  static func hash(_ rawToken: String) -> String {
    sha256Hex(rawToken)
  }

  private static func sha256Hex(_ value: String) -> String {
    let digest = SHA256.hash(data: Data(value.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static func base64URLEncode(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
