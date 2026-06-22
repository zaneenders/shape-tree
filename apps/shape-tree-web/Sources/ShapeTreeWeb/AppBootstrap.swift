import Foundation
import HTML
import Hummingbird
import NIOCore
import ShapeTreeWebAuth
import ShapeTreeWebCore

extension ShapeTreeWeb {
  static func configureRouter(
    _ router: Router<AppRequestContext>,
    store: ContentStore,
    indexSlug: String,
    auth: AuthServices,
    rateLimiter: LoginRateLimiter = LoginRateLimiter()
  ) {
    AuthRoutes.addSessionMiddleware(to: router, auth: auth)

    let homeSlug = store.indexPost?.slug ?? indexSlug

    router.get { _, _ in
      WebPages.shell(store: store, homeSlug: homeSlug).makeHTMLResponse()
    }

    AuthRoutes.addRoutes(
      to: router,
      auth: auth,
      rateLimiter: rateLimiter,
      spaLoginPage: { next in
        let safeNext = AuthEmail.normalizedWasmNextPath(next)
        return WebPages.shell(
          store: store,
          homeSlug: homeSlug,
          documentTitle: "Sign in · \(store.siteTitle)",
          bootLogin: true,
          loginNext: safeNext
        ).makeHTMLResponse()
      },
      spaVerifyPage: { token, next in
        let verifyToken = token.flatMap { $0.isEmpty ? nil : $0 }
        return WebPages.shell(
          store: store,
          homeSlug: homeSlug,
          documentTitle: verifyToken == nil
            ? "Sign in failed · \(store.siteTitle)"
            : "Confirm sign in · \(store.siteTitle)",
          bootVerify: true,
          verifyToken: verifyToken,
          verifyNext: AuthEmail.normalizedWasmNextPath(next)
        ).makeHTMLResponse()
      }
    )

    NavContentRoutes.register(on: router, store: store)
    LoginContentRoutes.register(on: router, store: store)
    PostContentRoutes.register(on: router, store: store)

    WasmPostRoutes.register(on: router, store: store, homeSlug: homeSlug)

    ClientRoutes.register(on: router)
  }

  static func parsePrivateDirectories(_ raw: String?) -> Set<String> {
    guard let raw else { return [] }
    let dirs = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    return Set(dirs.filter { !$0.isEmpty })
  }
}
