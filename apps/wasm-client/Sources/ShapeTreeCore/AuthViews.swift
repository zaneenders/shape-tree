import HTML
import JavaScriptKit

/// Auth chrome rendered entirely in Swift. Forms are real POSTs; the server
/// replies with redirects, so no client-side fetch/JSON is involved.
enum AuthViews {
  static func renderLogin(into main: HTMLElement, next: String?) {
    setHTML(main, loginView(next: next))
  }

  static func renderCheckEmail(into main: HTMLElement) {
    setHTML(main, checkEmailView())
  }

  static func renderVerifyConfirm(into main: HTMLElement, token: String, next: String?) {
    setHTML(main, verifyConfirmView(token: token, next: next))
  }

  static func renderVerifyFailed(into main: HTMLElement) {
    setHTML(main, verifyFailedView())
  }

  private static func loginView(next: String?) -> HTML {
    article {
      h1 { "Sign in" }
      p { "Enter your email and we'll send you a sign-in link." }
      form(attrs: [.class("login-form"), .method("post"), .action("/auth/login")]) {
        label(attrs: [.forID("login-email")]) { "Email" }
        input(attrs: [
          .id("login-email"),
          .name("email"),
          .type("email"),
          .autocomplete("email"),
          .required,
        ])
        if let next {
          hiddenField(name: "next", value: next)
        }
        button(attrs: [.type("submit")]) { "Send link" }
      }
    }
  }

  private static func checkEmailView() -> HTML {
    article {
      h1 { "Check your email" }
      p { "If your address is allowed, you will receive a sign-in link shortly." }
      p {
        a(attrs: [.href("/login"), .class("nav-login-link")]) { "Back to sign in" }
      }
    }
  }

  private static func verifyConfirmView(token: String, next: String?) -> HTML {
    article {
      h1 { "Confirm sign in" }
      p { "Click below to finish signing in on this device." }
      form(attrs: [.class("verify-form"), .method("post"), .action("/auth/verify")]) {
        hiddenField(name: "token", value: token)
        if let next {
          hiddenField(name: "next", value: next)
        }
        button(attrs: [.type("submit")]) { "Sign in" }
      }
    }
  }

  private static func verifyFailedView() -> HTML {
    article {
      h1 { "Link expired or invalid" }
      p { "This sign-in link may have expired or already been used." }
      p {
        a(attrs: [.href("/login"), .class("nav-login-link")]) { "Request a new link" }
      }
    }
  }
}
