import Foundation
import HTML
import Hummingbird
import ShapeTreeWebAssets
import ShapeTreeWebCore

enum AuthPages {
  static func login(
    next: String?,
    siteURL: String,
    siteTitle: String,
    loginPost: Post? = nil
  ) -> Response {
    let form = loginForm(next: next)
    let body: HTML
    if let loginPost {
      let rendered = substituteLoginForm(in: loginPost.bodyHTML, formHTML: form.render())
      body = article {
        h1 { loginPost.title }
        HTML.raw(rendered)
      }
    } else {
      body = article {
        h1 { "Sign in" }
        p { "Enter your email and we will send you a sign-in link." }
        form
      }
    }
    return pageShell(title: "Sign in | \(siteTitle)", body: body).makeHTMLResponse()
  }

  static func checkEmail(siteURL: String, siteTitle: String) -> Response {
    let body = article {
      h1 { "Check your email" }
      p { "If your address is allowed, you will receive a sign-in link shortly." }
      p {
        a(attrs: [.href("/login")]) { "Back to sign in" }
      }
    }
    return pageShell(title: "Check your email | \(siteTitle)", body: body).makeHTMLResponse()
  }

  static func verifyConfirm(token: String, next: String?, siteURL: String, siteTitle: String) -> Response {
    let body = article {
      h1 { "Confirm sign in" }
      p { "Click below to finish signing in on this device." }
      form(attrs: [.method("post"), .action("/auth/verify")]) {
        hiddenField(name: "token", value: token)
        if let next, !next.isEmpty {
          hiddenField(name: "next", value: next)
        }
        button(attrs: [.type("submit")]) { "Sign in" }
      }
    }
    return pageShell(title: "Confirm sign in | \(siteTitle)", body: body).makeHTMLResponse()
  }

  static func verifyFailed(siteURL: String, siteTitle: String) -> Response {
    let body = article {
      h1 { "Link expired or invalid" }
      p { "This sign-in link may have expired or already been used." }
      p {
        a(attrs: [.href("/login")]) { "Request a new link" }
      }
    }
    return pageShell(title: "Sign in failed | \(siteTitle)", body: body).makeHTMLResponse()
  }

  private static func pageShell(title: String, body: HTML) -> HTML {
    document(lang: "en") {
      HTML.void(.meta, attrs: [.charset("utf-8"), .name("viewport"), .content("width=device-width, initial-scale=1")])
      HTML.tag(.title) { title }
      HTML.raw("<style>\n\(auth_css)\n</style>")
    } body: {
      body
    }
  }

  private static func loginForm(next: String?) -> HTML {
    form(attrs: [.method("post"), .action("/auth/login")]) {
      label(attrs: [.forID("email")]) { "Email" }
      HTML.void(.input, attrs: [.id("email"), .name("email"), .type("email"), .autocomplete("email"), .required])
      if let next, !next.isEmpty {
        hiddenField(name: "next", value: next)
      }
      button(attrs: [.type("submit")]) { "Send link" }
    }
  }

  /// Substitutes the login form into a rendered markdown body at the `{{login}}`
  /// marker. When the marker is absent the form is appended to the body.
  private static func substituteLoginForm(in bodyHTML: String, formHTML: String) -> String {
    let placeholder = "{{login}}"
    if bodyHTML.contains(placeholder) {
      return
        bodyHTML
        .replacingOccurrences(of: "<p>\(placeholder)</p>", with: formHTML)
        .replacingOccurrences(of: placeholder, with: formHTML)
    }
    return bodyHTML + "\n" + formHTML
  }
}
