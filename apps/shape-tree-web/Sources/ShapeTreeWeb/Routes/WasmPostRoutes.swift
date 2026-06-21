import Foundation
import Hummingbird
import NIOCore
import ShapeTreeWebAssets
import ShapeTreeWebAuth
import ShapeTreeWebCore

enum WasmPostRoutes {
  static func register(on router: Router<AppRequestContext>, store: ContentStore) {
    guard PostWasmAsset.isAvailable else { return }

    router.get("wasm/wasms/:slug") { _, context in
      try wasmBytesResponse(context: context)
    }
    router.head("wasm/wasms/:slug") { _, context in
      try wasmBytesResponse(context: context, head: true)
    }

    router.get("wasm/posts/:slug") { _, context in
      try wasmPostShellResponse(context: context, store: store)
    }
    router.head("wasm/posts/:slug") { _, context in
      try wasmPostShellResponse(context: context, store: store, head: true)
    }
  }

  private static func wasmBytesResponse(context: AppRequestContext, head: Bool = false) throws -> Response {
    let rawSlug = try context.parameters.require("slug")
    guard let wasm = PostWasmAsset.wasm(forSlug: rawSlug) else {
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
    head: Bool = false
  ) throws -> Response {
    let rawSlug = try context.parameters.require("slug")
    let slug = PostWasmAsset.slugCandidates(for: rawSlug).first ?? rawSlug
    guard let post = store.post(slug: slug) else {
      throw HTTPError(.notFound)
    }
    if post.isPrivate, context.identity == nil {
      throw HTTPError(.notFound)
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
      initial: post,
      wasmBoot: (slug: slug, title: post.title)
    ).makeHTMLResponse()
  }
}
