import Foundation
import Hummingbird
import NIOCore
import ShapeTreeWebAssets

enum ClientRoutes {
  private static let basePath = "assets/client"

  static func register(on router: Router<BasicRequestContext>) {
    guard ClientAssetCatalog.isAvailable else { return }

    for relativePath in [
      "WASMClient.wasm",
      "index.js",
      "instantiate.js",
      "runtime.js",
      "platforms/browser.js",
      "browser_wasi_shim.js",
    ] {
      let route = RouterPath("\(basePath)/\(relativePath)")
      router.get(route) { request, _ in
        try assetResponse(for: relativePath, head: request.method == .head)
      }
      router.head(route) { request, _ in
        try assetResponse(for: relativePath, head: true)
      }
    }
  }

  private static func assetResponse(for relativePath: String, head: Bool) throws -> Response {
    guard let entry = ClientAssetCatalog.entry(forRelativePath: relativePath) else {
      throw HTTPError(.notFound)
    }

    switch entry {
    case .script(let body):
      return cachedResponse(
        contentType: "application/javascript; charset=utf-8",
        body: head ? ByteBuffer() : ByteBuffer(string: body)
      )
    case .wasm(let bytes):
      return cachedResponse(
        contentType: "application/wasm",
        body: head ? ByteBuffer() : ByteBuffer(bytes: bytes)
      )
    }
  }

  private static func cachedResponse(contentType: String, body: ByteBuffer) -> Response {
    let cacheControl =
      contentType.contains("wasm")
      ? "no-cache"
      : "public, max-age=60"
    return Response(
      status: .ok,
      headers: [
        .contentType: contentType,
        .cacheControl: cacheControl,
      ],
      body: .init(byteBuffer: body)
    )
  }
}
