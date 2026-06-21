import Foundation
import HTMX
import Hummingbird

enum AuthMiddleware {
  static func loginRedirectURL(next: String?) -> String {
    guard let next, !next.isEmpty, next.hasPrefix("/"), !next.hasPrefix("//") else {
      return "/login"
    }
    let encoded = next.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? next
    return "/login?next=\(encoded)"
  }

  static func unauthenticatedResponse(request: Request, next: String?) -> Response {
    let loginURL = loginRedirectURL(next: next)
    if request.headers[HTMX.Headers.Request.request] != nil {
      var headers = HTTPFields()
      headers.append(HTMX.redirect(url: loginURL))
      return Response(
        status: .unauthorized,
        headers: headers,
        body: .init())
    }
    return Response(
      status: .seeOther,
      headers: [.location: loginURL],
      body: .init())
  }

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
