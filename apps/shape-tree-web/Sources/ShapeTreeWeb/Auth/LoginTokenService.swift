import Crypto
import Foundation

enum LoginTokenService {
  static func generate() -> (raw: String, hash: String) {
    var bytes = [UInt8](repeating: 0, count: 32)
    let status = bytes.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
    }
    precondition(status == errSecSuccess)
    let raw = base64URLEncode(Data(bytes))
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
