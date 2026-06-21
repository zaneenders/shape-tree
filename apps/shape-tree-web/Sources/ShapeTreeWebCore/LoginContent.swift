import Foundation

/// JSON body for `GET /api/get-login-content`.
public struct LoginContentResponse: Codable, Sendable, Equatable {
  public var title: String
  public var bodyHTML: String
  public var next: String?

  public init(title: String, bodyHTML: String, next: String? = nil) {
    self.title = title
    self.bodyHTML = bodyHTML
    self.next = next
  }
}

extension ContentStore {
  public func loginContentResponse(next: String?) -> LoginContentResponse {
    if let loginPost {
      return LoginContentResponse(
        title: loginPost.title,
        bodyHTML: Self.bodyHTMLForLoginSPA(loginPost.bodyHTML),
        next: next
      )
    }
    return LoginContentResponse(
      title: "Sign in",
      bodyHTML: "<p>Enter your email and we will send you a sign-in link.</p>",
      next: next
    )
  }

  static func bodyHTMLForLoginSPA(_ bodyHTML: String) -> String {
    let placeholder = "{{login}}"
    var html = bodyHTML
    html = html.replacingOccurrences(of: "<p>\(placeholder)</p>", with: "")
    html = html.replacingOccurrences(of: placeholder, with: "")
    return html.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
