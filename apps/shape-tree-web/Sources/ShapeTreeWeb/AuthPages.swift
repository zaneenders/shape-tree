import Foundation
import Hummingbird
import NIOCore
import ShapeTreeWebAuth

enum AuthPages {
  static func login(next: String?) -> Response {
    let nextValue = next.flatMap { AuthEmail.normalizedWasmNextPath($0) } ?? "/"
    let escapedNext = escapeHTML(nextValue)
    return htmlPage(
      title: "Sign in",
      body: """
        <main class="auth-page">
          <h1>Sign in</h1>
          <p>Enter your email and we will send a one-time sign-in link.</p>
          <form method="POST" action="/auth/login" class="auth-form">
            <label>
              Email
              <input type="email" name="email" required autocomplete="email" />
            </label>
            <input type="hidden" name="next" value="\(escapedNext)" />
            <button type="submit">Send sign-in link</button>
          </form>
        </main>
        """
    )
  }

  static func checkEmail() -> Response {
    htmlPage(
      title: "Check your email",
      body: """
        <main class="auth-page">
          <h1>Check your email</h1>
          <p>If an account exists for that address, we sent a sign-in link. The link expires soon and works once.</p>
          <p><a href="/login">Back to sign in</a></p>
        </main>
        """
    )
  }

  static func verify(token: String?, next: String?) -> Response {
    let nextValue = next.flatMap { AuthEmail.normalizedWasmNextPath($0) } ?? "/"
    let escapedNext = escapeHTML(nextValue)

    if let token, !token.isEmpty {
      let escapedToken = escapeHTML(token)
      return htmlPage(
        title: "Confirm sign in",
        body: """
          <main class="auth-page">
            <h1>Confirm sign in</h1>
            <p>Click continue to finish signing in.</p>
            <form method="POST" action="/auth/verify" class="auth-form">
              <input type="hidden" name="token" value="\(escapedToken)" />
              <input type="hidden" name="next" value="\(escapedNext)" />
              <button type="submit">Continue</button>
            </form>
          </main>
          """
      )
    }

    return htmlPage(
      title: "Sign-in link invalid",
      body: """
        <main class="auth-page">
          <h1>Sign-in link invalid</h1>
          <p>This link is missing, expired, or already used.</p>
          <p><a href="/login">Request a new sign-in link</a></p>
        </main>
        """
    )
  }

  private static func htmlPage(title: String, body: String) -> Response {
    let escapedTitle = escapeHTML(title)
    let html = """
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>\(escapedTitle)</title>
        <style>
          :root { color-scheme: light dark; }
          body {
            margin: 0;
            min-height: 100vh;
            font-family: system-ui, sans-serif;
            color: CanvasText;
            background: Canvas;
          }
          .auth-page {
            width: min(28rem, 100% - 2rem);
            margin: 2rem auto;
          }
          .auth-form {
            display: grid;
            gap: 0.75rem;
          }
          .auth-form label {
            display: grid;
            gap: 0.35rem;
            font-size: 0.9rem;
          }
          .auth-form input[type="email"] {
            font: inherit;
            padding: 0.5rem 0.65rem;
            border-radius: 6px;
            border: 1px solid color-mix(in srgb, CanvasText 25%, transparent);
            background: Canvas;
            color: CanvasText;
          }
          .auth-form button {
            font: inherit;
            padding: 0.55rem 0.9rem;
            border-radius: 6px;
            border: 1px solid color-mix(in srgb, CanvasText 25%, transparent);
            background: color-mix(in srgb, CanvasText 8%, Canvas);
            color: CanvasText;
            cursor: pointer;
          }
          a { color: LinkText; }
        </style>
      </head>
      <body>
        \(body)
      </body>
      </html>
      """
    return Response(
      status: .ok,
      headers: [.contentType: "text/html; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: html))
    )
  }

  private static func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}
