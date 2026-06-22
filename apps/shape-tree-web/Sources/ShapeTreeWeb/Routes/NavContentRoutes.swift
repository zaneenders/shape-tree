import Foundation
import Hummingbird
import NIOCore
import ShapeTreeWebAuth
import ShapeTreeWebCore

enum NavContentRoutes {
  static func register(on router: Router<AppRequestContext>, store: ContentStore) {
    router.get("api/get-nav-content") { _, context in
      let viewer = NavViewer(
        isAuthenticated: context.identity != nil,
        email: context.identity?.email
      )
      let payload = store.navContentResponse(viewer: viewer)
      return try jsonResponse(payload)
    }
  }

  private static func jsonResponse(_ payload: NavContentResponse) throws -> Response {
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
