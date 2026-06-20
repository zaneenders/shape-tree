import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore

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

enum AuthRoutes {
  static func addRoutes<C: AuthRequestContext & SessionRequestContext & RemoteAddressRequestContext>(
    to router: Router<C>,
    auth: AuthServices,
    rateLimiter: LoginRateLimiter,
    siteTitle: String
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
    }

    router.get("login") { request, _ in
      let next = request.uri.queryParameters.get("next")
      return AuthPages.login(next: next, siteURL: auth.siteURL, siteTitle: siteTitle)
    }

    router.post("auth/login") { request, context async throws -> Response in
      let body = try await request.body.collect(upTo: 16 * 1024)
      let fields = FormParser.parseURLForm(String(buffer: body))
      let email = AuthMiddleware.normalizedEmail(fields["email"] ?? "")
      let next = AuthMiddleware.safeNextPath(fields["next"])
      let ip = context.remoteAddress?.ipAddress ?? "unknown"

      guard await rateLimiter.allow(email: email, ip: ip) else {
        context.logger.warning("Login rate limited for \(email)")
        return AuthPages.checkEmail(siteURL: auth.siteURL, siteTitle: siteTitle)
      }

      if let user = try await auth.database.user(email: email, logger: context.logger) {
        let (rawToken, tokenHash) = LoginTokenService.generate()
        let expiresAt = Date.now + Double(auth.settings.tokenTTL.components.seconds)
        try await auth.database.createLoginToken(
          userID: user.id,
          tokenHash: tokenHash,
          expiresAt: expiresAt,
          logger: context.logger
        )
        if let smtp = auth.smtp {
          try await sendLoginEmail(
            smtp: smtp,
            to: user.email,
            siteURL: auth.siteURL,
            rawToken: rawToken
          )
        } else {
          context.logger.notice("SMTP not configured; login link for \(user.email) not sent")
        }
      }

      _ = next
      return AuthPages.checkEmail(siteURL: auth.siteURL, siteTitle: siteTitle)
    }

    router.get("auth/verify") { request, _ async -> Response in
      guard let token = request.uri.queryParameters.get("token"), !token.isEmpty else {
        return AuthPages.verifyFailed(siteURL: auth.siteURL, siteTitle: siteTitle)
      }
      return AuthPages.verifyConfirm(token: token, siteURL: auth.siteURL, siteTitle: siteTitle)
    }

    router.post("auth/verify") { request, context async throws -> Response in
      guard sameOrigin(request: request, siteURL: auth.siteURL) else {
        throw HTTPError(.forbidden)
      }
      let body = try await request.body.collect(upTo: 16 * 1024)
      let fields = FormParser.parseURLForm(String(buffer: body))
      guard let rawToken = fields["token"], !rawToken.isEmpty else {
        return AuthPages.verifyFailed(siteURL: auth.siteURL, siteTitle: siteTitle)
      }

      let tokenHash = LoginTokenService.hash(rawToken)
      guard
        let token = try await auth.database.loginToken(hash: tokenHash, logger: context.logger),
        let user = try await auth.database.user(id: token.userID, logger: context.logger)
      else {
        return AuthPages.verifyFailed(siteURL: auth.siteURL, siteTitle: siteTitle)
      }

      try await auth.database.deleteLoginToken(id: token.id, logger: context.logger)
      context.sessions.setSession(user.id, expiresIn: auth.settings.sessionTTL)

      let redirect = AuthMiddleware.safeNextPath(fields["next"]) ?? "/"
      return Response(
        status: .seeOther,
        headers: [.location: redirect],
        body: .init())
    }

    router.post("auth/logout") { request, context async throws -> Response in
      guard sameOrigin(request: request, siteURL: auth.siteURL) else {
        throw HTTPError(.forbidden)
      }
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
    rawToken: String
  ) async throws {
    let link = "\(siteURL)/auth/verify?token=\(rawToken)"
    let email = smtp.makeEmail(
      to: recipient,
      subject: "Sign in to \(siteURL)",
      body: """
        Sign in to \(siteURL)

        \(link)

        This link expires in 15 minutes and can only be used once.
        If you did not request this email, you can ignore it.
        """
    )
    try await SMTPClient.send(email: email, settings: smtp.connection)
  }

  private static func sameOrigin(request: Request, siteURL: String) -> Bool {
    guard let siteHost = URL(string: siteURL)?.host else { return true }
    if let origin = request.headers[.origin], let originHost = URL(string: origin)?.host {
      return originHost == siteHost
    }
    if let referer = request.headers[.referer], let refererHost = URL(string: referer)?.host {
      return refererHost == siteHost
    }
    return true
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
