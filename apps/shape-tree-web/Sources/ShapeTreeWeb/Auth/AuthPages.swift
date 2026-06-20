import Foundation
import Hummingbird

enum AuthPages {
  static func login(next: String?, siteURL: String, siteTitle: String) -> Response {
    let nextField: String
    if let next, !next.isEmpty {
      let escaped = escapeHTML(next)
      nextField = #"<input type="hidden" name="next" value="\#(escaped)">"#
    } else {
      nextField = ""
    }
    let html = pageShell(
      title: "Sign in | \(siteTitle)",
      body: """
        <article>
          <h1>Sign in</h1>
          <p>Enter your email and we will send you a sign-in link.</p>
          <form method="post" action="/auth/login">
            <label for="email">Email</label>
            <input id="email" name="email" type="email" autocomplete="email" required>
            \(nextField)
            <button type="submit">Send link</button>
          </form>
        </article>
        """,
      siteTitle: siteTitle
    )
    return html.makeHTMLResponse()
  }

  static func checkEmail(siteURL: String, siteTitle: String) -> Response {
    let html = pageShell(
      title: "Check your email | \(siteTitle)",
      body: """
        <article>
          <h1>Check your email</h1>
          <p>If your address is allowed, you will receive a sign-in link shortly.</p>
          <p><a href="/login">Back to sign in</a></p>
        </article>
        """,
      siteTitle: siteTitle
    )
    return html.makeHTMLResponse()
  }

  static func verifyConfirm(token: String, siteURL: String, siteTitle: String) -> Response {
    let escaped = escapeHTML(token)
    let html = pageShell(
      title: "Confirm sign in | \(siteTitle)",
      body: """
        <article>
          <h1>Confirm sign in</h1>
          <p>Click below to finish signing in on this device.</p>
          <form method="post" action="/auth/verify">
            <input type="hidden" name="token" value="\(escaped)">
            <button type="submit">Sign in</button>
          </form>
        </article>
        """,
      siteTitle: siteTitle
    )
    return html.makeHTMLResponse()
  }

  static func verifyFailed(siteURL: String, siteTitle: String) -> Response {
    let html = pageShell(
      title: "Sign in failed | \(siteTitle)",
      body: """
        <article>
          <h1>Link expired or invalid</h1>
          <p>This sign-in link may have expired or already been used.</p>
          <p><a href="/login">Request a new link</a></p>
        </article>
        """,
      siteTitle: siteTitle
    )
    return html.makeHTMLResponse()
  }

  private static func pageShell(title: String, body: String, siteTitle: String) -> String {
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(escapeHTML(title))</title>
      <style>
        :root { color-scheme: light dark; }
        body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
        article { background: color-mix(in srgb, currentColor 5%, transparent); padding: 1.5rem; border-radius: 0.5rem; }
        form { display: flex; flex-direction: column; gap: 0.75rem; }
        input, button { font: inherit; padding: 0.5rem; }
        button { align-self: flex-start; cursor: pointer; }
        a { color: inherit; }
      </style>
    </head>
    <body>
      \(body)
    </body>
    </html>
    """
  }

  private static func escapeHTML(_ text: String) -> String {
    text
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}

extension String {
  fileprivate func makeHTMLResponse() -> Response {
    Response(
      status: .ok,
      headers: [.contentType: "text/html; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: self))
    )
  }
}
