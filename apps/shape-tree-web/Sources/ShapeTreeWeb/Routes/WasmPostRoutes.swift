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
      let slug = try context.parameters.require("slug")
      guard let wasm = PostWasmAsset.wasm(forSlug: slug) else {
        throw HTTPError(.notFound)
      }
      return Response(
        status: .ok,
        headers: [
          .contentType: "application/wasm",
          .cacheControl: "no-cache",
        ],
        body: .init(byteBuffer: ByteBuffer(bytes: wasm))
      )
    }

    router.get("wasm/posts/:slug") { _, context in
      let slug = try context.parameters.require("slug")
      guard let post = store.post(slug: slug) else {
        throw HTTPError(.notFound)
      }
      if post.isPrivate, context.identity == nil {
        throw HTTPError(.notFound)
      }
      return WebPages.wasmPostShell(slug: slug, title: post.title, siteTitle: store.siteTitle)
        .makeHTMLResponse()
    }
  }
}
