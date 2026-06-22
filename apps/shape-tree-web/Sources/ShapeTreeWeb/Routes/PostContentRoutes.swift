import Foundation
import Hummingbird
import NIOCore
import ShapeTreeWebAuth
import ShapeTreeWebCore

enum PostContentRoutes {
  static func register(on router: Router<AppRequestContext>, store: ContentStore) {
    router.get("api/get-post-content/:slug") { _, context in
      let rawSlug = try context.parameters.require("slug")
      guard let post = WebPages.post(forSlug: rawSlug, store: store),
        WebPages.canView(post, isAuthenticated: context.identity != nil),
        !post.isLogin
      else {
        throw HTTPError(.notFound)
      }
      let payload = store.postContentResponse(for: post)
      return try jsonResponse(payload)
    }
  }

  private static func jsonResponse(_ payload: PostContentResponse) throws -> Response {
    let data = try JSONEncoder().encode(payload)
    return Response(
      status: .ok,
      headers: [
        .contentType: "application/json; charset=utf-8",
        .cacheControl: "private, no-store",
      ],
      body: .init(byteBuffer: ByteBuffer(data: data))
    )
  }
}
