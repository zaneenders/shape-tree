import Foundation
import Hummingbird
import RegexBuilder

enum AuthEmailError: Error {
  case invalid
}

package enum AuthEmail {
  private static func normalizedEmail(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  /// Normalizes and validates an email address, returning the normalized value
  /// only when it matches a basic `local@domain.tld` shape. Returns `nil` for
  /// malformed input.
  package static func validatedEmail(_ raw: String) -> String? {
    let normalized = normalizedEmail(raw)
    let localCharacter = CharacterClass(
      ("a"..."z"),
      ("0"..."9"),
      .anyOf("!#$%&'*+/=?^_`{|}~.-")
    )
    let domainLabel = OneOrMore(
      CharacterClass(("a"..."z"), ("0"..."9"), .anyOf("-"))
    )
    let emailRegex = Regex {
      OneOrMore(localCharacter)
      "@"
      OneOrMore {
        domainLabel
        "."
      }
      Repeat(("a"..."z"), 2...)
    }
    guard normalized.wholeMatch(of: emailRegex) != nil else { return nil }
    return normalized
  }

  package static func safeNextPath(_ raw: String?) -> String? {
    guard let raw, raw.hasPrefix("/"), !raw.hasPrefix("//") else {
      return nil
    }
    return raw
  }

  package static func wasmPostPath(slug: String) -> String {
    "/wasm/posts/\(slug)"
  }

  /// Accepts wasm post paths and legacy `/posts/:slug` targets; returns a wasm route or `/`.
  package static func normalizedWasmNextPath(_ raw: String?) -> String? {
    guard let raw = safeNextPath(raw) else { return nil }
    if raw == "/" { return raw }
    if raw.hasPrefix("/wasm/posts/") { return raw }
    if raw.hasPrefix("/posts/") {
      let slug = String(raw.dropFirst("/posts/".count))
      guard !slug.isEmpty, !slug.contains("/") else { return nil }
      return wasmPostPath(slug: slug)
    }
    return nil
  }

  /// Appends `signed-in=1` so the SPA can refresh nav after magic-link verify.
  package static func signedInRedirect(to path: String) -> String {
    if path.contains("?") {
      return "\(path)&signed-in=1"
    }
    return "\(path)?signed-in=1"
  }
}
