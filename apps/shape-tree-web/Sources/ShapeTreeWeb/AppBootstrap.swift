import Foundation
import HTML
import Hummingbird
import NIOCore
import ShapeTreeWebAssets
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

    router.get("posts/:slug") { request, context in
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug) else {
        return WebPages.notFoundResponse(store: store, homeSlug: homeSlug)
      }
      if post.isLogin {
        return Response(
          status: .seeOther,
          headers: [.location: "/login"],
          body: .init())
      }
      if post.isPrivate, context.identity == nil {
        return WebPages.notFoundResponse(store: store, homeSlug: homeSlug)
      }
      if PostWasmAsset.isAvailable, PostWasmAsset.wasm(forSlug: post.slug) != nil {
        return Response(
          status: .seeOther,
          headers: [.location: "/wasm/posts/\(post.slug)"],
          body: .init())
      }
      return WebPages.notFoundResponse(store: store, homeSlug: homeSlug)
    }

    AuthRoutes.addRoutes(
      to: router,
      auth: auth,
      rateLimiter: rateLimiter,
      spaLoginPage: { next in
        let safeNext = AuthEmail.safeNextPath(next)
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
          verifyNext: next
        ).makeHTMLResponse()
      }
    )

    NavContentRoutes.register(on: router, store: store)
    LoginContentRoutes.register(on: router, store: store)

    WasmPostRoutes.register(on: router, store: store, homeSlug: homeSlug)

    ClientRoutes.register(on: router)
  }

  static func parsePrivateDirectories(_ raw: String?) -> Set<String> {
    guard let raw else { return [] }
    let dirs = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    return Set(dirs.filter { !$0.isEmpty })
  }
}
