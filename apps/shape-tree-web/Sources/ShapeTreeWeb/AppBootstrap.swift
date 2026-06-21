import Foundation
import HTML
import HTMX
import Hummingbird
import NIOCore
import ShapeTreeWebAuth
import ShapeTreeWebCore

extension ShapeTreeWeb {
  static func configureRouter(
    _ router: Router<AppRequestContext>,
    store: ContentStore,
    initial: Post,
    indexSlug: String,
    auth: AuthServices,
    rateLimiter: LoginRateLimiter = LoginRateLimiter()
  ) {
    AuthRoutes.addSessionMiddleware(to: router, auth: auth)

    router.get { _, _ in
      WebPages.shell(store: store, initial: initial).makeHTMLResponse()
    }

    router.get("posts/:slug") { request, context in
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug) else {
        throw HTTPError(.notFound)
      }
      if post.isLogin {
        return Response(
          status: .seeOther,
          headers: [.location: "/login"],
          body: .init())
      }
      if post.isPrivate, context.identity == nil {
        throw HTTPError(.notFound)
      }
      return WebPages.shell(store: store, initial: post).makeHTMLResponse()
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

    router.get("htmx/content/posts/:slug") { request, context in
      try HTMX.requireRequest(request)
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug) else {
        throw HTTPError(.notFound)
      }
      if post.isLogin {
        throw HTTPError(.notFound)
      }
      if post.isPrivate, context.identity == nil {
        throw HTTPError(.notFound)
      }
      let fragment = WebPages.contentFragment(for: post, store: store)
      return htmlFragmentResponse(fragment)
    }

    AuthRoutes.addRoutes(
      to: router,
      auth: auth,
      rateLimiter: rateLimiter,
      siteTitle: store.siteTitle,
      loginPost: store.loginPost
    )

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
