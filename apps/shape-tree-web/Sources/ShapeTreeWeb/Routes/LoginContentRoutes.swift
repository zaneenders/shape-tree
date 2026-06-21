import Foundation
import Hummingbird
import NIOCore
import ShapeTreeWebAuth
import ShapeTreeWebCore

enum LoginContentRoutes {
  static func register(on router: Router<AppRequestContext>, store: ContentStore) {
    router.get("api/get-login-content") { request, _ in
      let next = AuthEmail.safeNextPath(request.uri.queryParameters.get("next"))
      let payload = store.loginContentResponse(next: next)
      return try jsonResponse(payload)
    }
  }

  private static func jsonResponse(_ payload: LoginContentResponse) throws -> Response {
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
