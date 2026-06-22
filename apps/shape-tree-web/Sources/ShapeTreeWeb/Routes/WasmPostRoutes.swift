import Foundation
import Hummingbird
import HTTPTypes
import NIOCore
import ShapeTreeWebAssets
import ShapeTreeWebAuth
import ShapeTreeWebCore

enum WasmPostRoutes {
  static func register(
    on router: Router<AppRequestContext>,
    store: ContentStore,
    homeSlug: String
  ) {
    guard PostWasmAsset.isAvailable else { return }

    router.get("wasm/wasms/:slug") { request, context in
      if wantsHTMLDocument(request) {
        return try postShellRedirect(for: context)
      }
      return try wasmBytesResponse(context: context, store: store)
    }
    router.head("wasm/wasms/:slug") { request, context in
      if wantsHTMLDocument(request) {
        return try postShellRedirect(for: context, head: true)
      }
      return try wasmBytesResponse(context: context, store: store, head: true)
    }

    router.get("wasm/posts/:slug") { _, context in
      try wasmPostShellResponse(context: context, store: store, homeSlug: homeSlug)
    }
    router.head("wasm/posts/:slug") { _, context in
      try wasmPostShellResponse(context: context, store: store, homeSlug: homeSlug, head: true)
    }
  }

  private static func wasmBytesResponse(
    context: AppRequestContext,
    store: ContentStore,
    head: Bool = false
  ) throws -> Response {
    let rawSlug = try context.parameters.require("slug")
    guard let page = WebPages.wasmPage(
      forSlug: rawSlug,
      store: store,
      isAuthenticated: context.identity != nil
    ) else {
      throw HTTPError(.notFound)
    }
    if page.isLogin {
      throw HTTPError(.notFound)
    }
    guard let wasm = PostWasmAsset.wasm(forSlug: page.slug) else {
      throw HTTPError(.notFound)
    }
    return Response(
      status: .ok,
      headers: [
        .contentType: "application/wasm",
        .cacheControl: "no-cache",
      ],
      body: .init(byteBuffer: head ? ByteBuffer() : ByteBuffer(bytes: wasm))
    )
  }

  private static func wasmPostShellResponse(
    context: AppRequestContext,
    store: ContentStore,
    homeSlug: String,
    head: Bool = false
  ) throws -> Response {
    let rawSlug = try context.parameters.require("slug")
    guard let page = WebPages.wasmPage(
      forSlug: rawSlug,
      store: store,
      isAuthenticated: context.identity != nil
    ) else {
      if head {
        return Response(
          status: .notFound,
          headers: [.contentType: "text/html; charset=utf-8"],
          body: .init(byteBuffer: ByteBuffer())
        )
      }
      return WebPages.notFoundResponse(store: store, homeSlug: homeSlug)
    }
    if page.isLogin {
      let location = "/login"
      if head {
        return Response(
          status: .seeOther,
          headers: [.location: location],
          body: .init(byteBuffer: ByteBuffer())
        )
      }
      return Response(
        status: .seeOther,
        headers: [.location: location],
        body: .init())
    }
    if head {
      return Response(
        status: .ok,
        headers: [.contentType: "text/html; charset=utf-8"],
        body: .init(byteBuffer: ByteBuffer())
      )
    }
    return WebPages.shell(
      store: store,
      homeSlug: homeSlug,
      documentTitle: "\(page.title) · \(store.siteTitle)",
      wasmBoot: (slug: page.slug, title: page.title)
    ).makeHTMLResponse()
  }

  /// Top-level browser navigations to the wasm asset URL should load the HTML shell
  /// at `/wasm/posts/:slug` instead of a bare 404 from the bytes endpoint.
  private static func postShellRedirect(for context: AppRequestContext, head: Bool = false) throws -> Response {
    let slug = try context.parameters.require("slug")
    return Response(
      status: .seeOther,
      headers: [.location: "/wasm/posts/\(slug)"],
      body: .init(byteBuffer: head ? ByteBuffer() : ByteBuffer())
    )
  }

  private static let secFetchDest = HTTPField.Name("Sec-Fetch-Dest")!

  private static func wantsHTMLDocument(_ request: Request) -> Bool {
    request.headers[secFetchDest] == "document"
  }
}
