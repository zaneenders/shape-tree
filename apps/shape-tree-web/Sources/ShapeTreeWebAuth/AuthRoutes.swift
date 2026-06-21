import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore
import ShapeTreeWebCore
import ShapeTreeWebEmail

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
    siteTitle: String,
    loginPost: Post? = nil
  ) where C.Identity == User, C.Session == UUID {
    router.get("login") { request, _ in
      let next = request.uri.queryParameters.get("next")
      return AuthPages.login(
        next: next,
        siteURL: auth.siteURL,
        siteTitle: siteTitle,
        loginPost: loginPost
      )
    }

    router.post("auth/login") { request, context async throws -> Response in
      let body = try await request.body.collect(upTo: 16 * 1024)
      let fields = FormParser.parseURLForm(String(buffer: body))
      let email = AuthMiddleware.normalizedEmail(fields["email"] ?? "")
      let next = AuthMiddleware.safeNextPath(fields["next"])
      let ip = context.remoteAddress?.ipAddress ?? "unknown"

      guard await rateLimiter.allow(email: email, ip: ip) else {
        context.logger.warning("Login rate limited for \(email) from \(ip)")
        return AuthPages.checkEmail(siteURL: auth.siteURL, siteTitle: siteTitle)
      }

      let (rawToken, tokenHash) = LoginTokenService.generate()
      let expiresAt = Date.now + Double(auth.settings.tokenTTL.components.seconds)

      if let user = try await auth.database.user(email: email, logger: context.logger) {
        Task {
          try await auth.database.createLoginToken(
            userID: user.id,
            tokenHash: tokenHash,
            expiresAt: expiresAt,
            logger: context.logger
          )
          try await sendLoginEmail(
            smtp: auth.smtp,
            to: user.email,
            siteURL: auth.siteURL,
            rawToken: rawToken,
            next: next,
            tokenTTLMinutes: auth.settings.tokenTTLMinutes
          )
        }
      }

      return AuthPages.checkEmail(siteURL: auth.siteURL, siteTitle: siteTitle)
    }

    router.get("auth/verify") { request, _ async -> Response in
      guard let token = request.uri.queryParameters.get("token"), !token.isEmpty else {
        return AuthPages.verifyFailed(siteURL: auth.siteURL, siteTitle: siteTitle)
      }
      let next = AuthMiddleware.safeNextPath(request.uri.queryParameters.get("next"))
      return AuthPages.verifyConfirm(
        token: token,
        next: next,
        siteURL: auth.siteURL,
        siteTitle: siteTitle
      )
    }

    router.post("auth/verify") { request, context async throws -> Response in
      let body = try await request.body.collect(upTo: 16 * 1024)
      let fields = FormParser.parseURLForm(String(buffer: body))
      guard let rawToken = fields["token"], !rawToken.isEmpty else {
        return AuthPages.verifyFailed(siteURL: auth.siteURL, siteTitle: siteTitle)
      }

      let tokenHash = LoginTokenService.hash(rawToken)
      guard
        let userID = try await auth.database.consumeLoginToken(hash: tokenHash, logger: context.logger),
        let user = try await auth.database.user(id: userID, logger: context.logger)
      else {
        return AuthPages.verifyFailed(siteURL: auth.siteURL, siteTitle: siteTitle)
      }

      context.sessions.setSession(user.id, expiresIn: auth.settings.sessionTTL)

      let redirect = AuthMiddleware.safeNextPath(fields["next"]) ?? "/"
      return Response(
        status: .seeOther,
        headers: [.location: redirect],
        body: .init())
    }

    router.post("auth/logout") { _, context async throws -> Response in
      context.sessions.clearSession()
      return Response(
        status: .seeOther,
        headers: [.location: "/"],
        body: .init())
    }
  }

  private static func sendLoginEmail(
    smtp: SMTPSettings,
    to recipient: String,
    siteURL: String,
    rawToken: String,
    next: String?,
    tokenTTLMinutes: Int
  ) async throws {
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
