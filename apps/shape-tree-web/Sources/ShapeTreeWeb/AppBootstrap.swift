import Foundation
import HTML
import HTMLNIO
import Hummingbird
import NIOCore
import ShapeTreeWebAuth
import ShapeTreeWebCore

extension ShapeTreeWeb {
  static func configureRouter(
    _ router: Router<AppRequestContext>,
    store: ContentStore,
    auth: AuthServices,
    rateLimiter: LoginRateLimiter = LoginRateLimiter()
  ) {
    AuthRoutes.addSessionMiddleware(to: router, auth: auth)
    router.add(middleware: NotFoundMiddleware(store: store))

    router.get { _, _ in
      WebPages.shell(store: store).makeHTMLResponse()
    }

    AuthRoutes.addRoutes(
      to: router,
      auth: auth,
      rateLimiter: rateLimiter,
      spaLoginPage: { _ in
        WebPages.shell(
          store: store,
          documentTitle: "Sign in · \(store.siteTitle)"
        ).makeHTMLResponse()
      },
      spaVerifyPage: { _, _ in
        WebPages.shell(store: store).makeHTMLResponse()
      },
      spaCheckEmailPage: {
        WebPages.shell(
          store: store,
          documentTitle: "Check your email · \(store.siteTitle)"
        ).makeHTMLResponse()
      }
    )

    NavContentRoutes.register(on: router, store: store)
    ContentRoutes.register(on: router, store: store)
    ClientRoutes.register(on: router)
  }

  static func parsePrivateDirectories(_ raw: String?) -> Set<String> {
    guard let raw else { return [] }
    let dirs = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    return Set(dirs.filter { !$0.isEmpty })
  }
}
