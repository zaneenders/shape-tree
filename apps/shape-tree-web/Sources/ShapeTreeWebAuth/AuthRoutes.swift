import Configuration
import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore
import ShapeTreeEmail

enum FormParser {
  static func parseURLForm(_ body: String) -> [String: String] {
    var fields: [String: String] = [:]
    for pair in body.split(separator: "&") {
      let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }
      let key = parts[0].replacingOccurrences(of: "+", with: " ")
      let value = parts[1].replacingOccurrences(of: "+", with: " ")
      fields[percentDecode(key)] = percentDecode(value)
    }
    return fields
  }

  private static func percentDecode(_ value: String) -> String {
    value.removingPercentEncoding ?? value
  }
}

package enum AuthRoutes {
  /// Registers the session middleware and authenticator. This must be called
  /// before any routes that read `context.identity` are added to the router,
  /// because Hummingbird only applies middleware to routes registered after it.
  package static func addSessionMiddleware<
    C: AuthRequestContext & SessionRequestContext & RemoteAddressRequestContext
  >(
    to router: Router<C>,
    auth: AuthServices
  ) where C.Identity == User, C.Session == UUID {
    let sessionConfig = SessionMiddlewareConfiguration(
      sessionCookieParameters: .init(
        name: "SESSION_ID",
        secure: auth.secureCookies,
        sameSite: .lax
      ),
      defaultSessionExpiration: auth.settings.sessionTTL
    )
    router.addMiddleware {
      SessionMiddleware(storage: auth.persist, configuration: sessionConfig)
      SessionAuthenticator(context: C.self) {
        (userID: UUID, context: UserRepositoryContext) async throws -> User? in
        try await auth.database.user(id: userID, logger: context.logger)
      }
    }
  }

  package static func addRoutes<C: AuthRequestContext & SessionRequestContext & RemoteAddressRequestContext>(
    to router: Router<C>,
    auth: AuthServices,
    rateLimiter: LoginRateLimiter,
    spaShellPage: @Sendable @escaping () -> Response
  ) where C.Identity == User, C.Session == UUID {
    router.get("login") { _, _ in
      spaShellPage()
    }

    router.get("auth/check-email") { _, _ in
      spaShellPage()
    }

    // Login is submitted via fetch from the SPA. Always return the same JSON body so we
    // never leak which emails are registered.
    router.post("auth/login") { request, context async throws -> Response in
      let body = try await request.body.collect(upTo: 16 * 1024)
      let fields = FormParser.parseURLForm(String(buffer: body))
      let next = AuthEmail.safeNextPath(fields["next"])
      let ip = context.remoteAddress?.ipAddress ?? "unknown"

      guard let email = AuthEmail.validatedEmail(fields["email"] ?? "") else {
        context.logger.warning("Rejected malformed login email from \(ip)")
        return loginAccepted()
      }

      guard await rateLimiter.allow(ip: ip) else {
        context.logger.warning("Login rate limited for \(email) from \(ip)")
        return loginAccepted()
      }

      let (rawToken, tokenHash) = LoginTokenService.generate()
      let expiresAt = Date.now + Double(auth.settings.tokenTTL.components.seconds)

      if let user = try await auth.database.user(email: email, logger: context.logger) {
        let log = context.logger
        Task {
          do {
            try await auth.database.createLoginToken(
              userID: user.id,
              tokenHash: tokenHash,
              expiresAt: expiresAt,
              logger: log
            )
            try await sendLoginEmail(
              config: auth.config,
              to: user.email,
              siteURL: auth.siteURL,
              rawToken: rawToken,
              next: next,
              tokenTTLMinutes: auth.settings.tokenTTLMinutes,
              logger: log
            )
          } catch {
            log.error("Failed to send login email", metadata: ["error": "\(error)"])
          }
        }
      }

      return loginAccepted()
    }

    router.get("auth/verify") { _, _ in
      spaShellPage()
    }

    // Verify is submitted via fetch from the SPA. Always return JSON so the client can
    // finish sign-in without a redirect.
    router.post("auth/verify") { request, context async throws -> Response in
      let body = try await request.body.collect(upTo: 16 * 1024)
      let fields = FormParser.parseURLForm(String(buffer: body))
      guard let rawToken = fields["token"], !rawToken.isEmpty else {
        return verifyRejected()
      }

      let tokenHash = LoginTokenService.hash(rawToken)
      guard
        let userID = try await auth.database.consumeLoginToken(hash: tokenHash, logger: context.logger),
        let user = try await auth.database.user(id: userID, logger: context.logger)
      else {
        return verifyRejected()
      }

      context.sessions.setSession(user.id, expiresIn: auth.settings.sessionTTL)

      let next = AuthEmail.safeNextPath(fields["next"]) ?? "/"
      return verifyAccepted(next: next)
    }

    router.post("auth/logout") { _, context async throws -> Response in
      context.sessions.clearSession()
      return redirect(to: "/")
    }
  }

  private static func redirect(to location: String) -> Response {
    Response(status: .seeOther, headers: [.location: location], body: .init())
  }

  private static func loginAccepted() -> Response {
    Response(
      status: .ok,
      headers: [.contentType: "application/json; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: #"{"ok":true}"#))
    )
  }

  private static func verifyAccepted(next: String) -> Response {
    let nextJSON = (try? JSONSerialization.data(withJSONObject: ["ok": true, "next": next]))
      .flatMap { String(data: $0, encoding: .utf8) } ?? #"{"ok":true,"next":"/"}"#
    return Response(
      status: .ok,
      headers: [.contentType: "application/json; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: nextJSON))
    )
  }

  private static func verifyRejected() -> Response {
    Response(
      status: .ok,
      headers: [.contentType: "application/json; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: #"{"ok":false}"#))
    )
  }

  private static func sendLoginEmail(
    config: ConfigReader,
    to recipient: String,
    siteURL: String,
    rawToken: String,
    next: String?,
    tokenTTLMinutes: Int,
    logger: Logger
  ) async throws {
    guard let smtp = SMTPSettings.load(from: config) else {
      logger.error(
        "SMTP is not configured. Set SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, and SMTP_FROM in apps/shape-tree-web/.env"
      )
      return
    }
    var link = "\(siteURL)/auth/verify?token=\(rawToken)"
    if let next, !next.isEmpty {
      let encoded = next.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? next
      link += "&next=\(encoded)"
    }
    let email = smtp.makeEmail(
      to: recipient,
      subject: "Sign in to \(siteURL)",
      body: """
        Sign in to \(siteURL)

        \(link)

        This link expires in \(tokenTTLMinutes) minutes and can only be used once.
        If you did not request this email, you can ignore it.
        """
    )
    try await SMTPClient.send(email: email, settings: smtp.connection)
  }
}

extension SocketAddress {
  fileprivate var ipAddress: String? {
    switch self {
    case .v4(let addr):
      return addr.host
    case .v6(let addr):
      return addr.host
    case .unixDomainSocket:
      return nil
    }
  }
}
