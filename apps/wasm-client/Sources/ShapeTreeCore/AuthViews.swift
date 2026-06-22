import JavaScriptKit

/// Auth chrome rendered entirely in Swift. Forms are real POSTs; the server
/// replies with redirects, so no client-side fetch/JSON is involved.
enum AuthViews {
  static func renderLogin(into main: JSObject, next: String?) {
    let nextField = next.map {
      "<input type=\"hidden\" name=\"next\" value=\"\(escapeAttr($0))\">"
    } ?? ""
    setHTML(
      main,
      """
      <article>
      <h1>Sign in</h1>
      <p>Enter your email and we'll send you a sign-in link.</p>
      <form class="login-form" method="post" action="/auth/login">
      <label for="login-email">Email</label>
      <input id="login-email" name="email" type="email" autocomplete="email" required>
      \(nextField)
      <button type="submit">Send link</button>
      </form>
      </article>
      """
    )
  }

  static func renderCheckEmail(into main: JSObject) {
    setHTML(
      main,
      """
      <article>
      <h1>Check your email</h1>
      <p>If your address is allowed, you will receive a sign-in link shortly.</p>
      <p><a href="/login" class="nav-login-link">Back to sign in</a></p>
      </article>
      """
    )
  }

  static func renderVerifyConfirm(into main: JSObject, token: String, next: String?) {
    let nextField = next.map {
      "<input type=\"hidden\" name=\"next\" value=\"\(escapeAttr($0))\">"
    } ?? ""
    setHTML(
      main,
      """
      <article>
      <h1>Confirm sign in</h1>
      <p>Click below to finish signing in on this device.</p>
      <form class="verify-form" method="post" action="/auth/verify">
      <input type="hidden" name="token" value="\(escapeAttr(token))">
      \(nextField)
      <button type="submit">Sign in</button>
      </form>
      </article>
      """
    )
  }

  static func renderVerifyFailed(into main: JSObject) {
    setHTML(
      main,
      """
      <article>
      <h1>Link expired or invalid</h1>
      <p>This sign-in link may have expired or already been used.</p>
      <p><a href="/login" class="nav-login-link">Request a new link</a></p>
      </article>
      """
    )
  }
}
