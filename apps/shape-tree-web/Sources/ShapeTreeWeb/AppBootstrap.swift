import Foundation
import HTML
import HTMX
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

    router.get("htmx/content/nav") { request, context in
      try HTMX.requireRequest(request)
      return WebPages.navigation(
        store: store,
        isAuthenticated: context.identity != nil
      ).makeHTMLResponse()
    }

    router.get("htmx/content/index") { request, _ in
      try HTMX.requireRequest(request)
      let post = store.indexPost ?? fallbackIndexPost(slug: indexSlug)
      let fragment = WebPages.contentFragment(for: post, store: store)
      return htmlFragmentResponse(fragment)
    }

    router.get("htmx/content/not-found") { request, _ in
      try HTMX.requireRequest(request)
      return htmlFragmentResponse(WebPages.notFoundFragment(store: store))
    }

    router.get("htmx/content/posts/:slug") { request, context in
      try HTMX.requireRequest(request)
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug) else {
        return htmlFragmentResponse(WebPages.notFoundFragment(store: store))
      }
      if post.isLogin {
        return htmlFragmentResponse(WebPages.notFoundFragment(store: store))
      }
      if post.isPrivate, context.identity == nil {
        return htmlFragmentResponse(WebPages.notFoundFragment(store: store))
      }
      let fragment = WebPages.contentFragment(for: post, store: store)
      return htmlFragmentResponse(fragment)
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

  static func htmlFragmentResponse(_ fragment: String) -> Response {
    Response(
      status: .ok,
      headers: [.contentType: "text/html; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: fragment))
    )
  }

  static func fallbackIndexPost(slug: String) -> Post {
    Post(
      slug: slug,
      title: "ShapeTree Web",
      date: .distantPast,
      tags: [],
      excerpt: nil,
      bodyMarkdown: "",
      bodyHTML: "",
      relativePath: "",
      isIndex: true
    )
  }
}
