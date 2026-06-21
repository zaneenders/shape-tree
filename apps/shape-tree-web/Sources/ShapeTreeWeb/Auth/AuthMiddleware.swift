import Foundation
import Hummingbird

enum AuthMiddleware {
  static func normalizedEmail(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  static func safeNextPath(_ raw: String?) -> String? {
    guard let raw, raw.hasPrefix("/"), !raw.hasPrefix("//") else {
      return nil
    }
    return raw
  }
}
