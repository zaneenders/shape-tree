import Hummingbird
import HTTPTypes
import NIOCore
import ShapeTreeWebCore

struct NotFoundMiddleware<Context: RequestContext>: RouterMiddleware {
  let store: ContentStore

  func handle(
    _ request: Request,
    context: Context,
    next: (Request, Context) async throws -> Response
  ) async throws -> Response {
    do {
      return try await next(request, context)
    } catch let error as HTTPError where error.status == .notFound {
      guard Self.wantsHTMLDocument(request) else { throw error }
      if request.method == .head {
        return Response(
          status: .notFound,
          headers: [.contentType: "text/html; charset=utf-8"],
          body: .init(byteBuffer: ByteBuffer())
        )
      }
      return WebPages.notFoundResponse(store: store)
    }
  }

  private static var secFetchDest: HTTPField.Name { HTTPField.Name("Sec-Fetch-Dest")! }

  private static func wantsHTMLDocument(_ request: Request) -> Bool {
    if request.headers[secFetchDest] == "document" { return true }
    if let accept = request.headers[.accept], accept.contains("text/html") { return true }
    return false
  }
}
