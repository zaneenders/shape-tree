import Foundation
import Hummingbird
import NIOCore
import ShapeTreeWebAuth

enum FitProtectedRoutes {
  private static let protectedFiles: [(path: String, contentType: String)] = [
    ("FitViewer.wasm", "application/wasm"),
    ("fit-viewer-bootstrap.js", "text/javascript; charset=utf-8"),
    ("sample.fit", "application/octet-stream"),
  ]

  static func register(
    on router: Router<AppRequestContext>,
    staticRoot: String
  ) {
    for file in protectedFiles {
      let filePath = (staticRoot as NSString).appendingPathComponent(file.path)
      router.get(RouterPath(file.path)) { _, context -> Response in
        guard context.identity != nil else {
          return Response(
            status: .seeOther,
            headers: [.location: "/login?next=/"],
            body: .init()
          )
        }
        do {
          let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
          return Response(
            status: .ok,
            headers: [.contentType: file.contentType],
            body: .init(byteBuffer: ByteBuffer(data: data))
          )
        } catch {
          return Response(status: .notFound)
        }
      }
    }
  }
}
