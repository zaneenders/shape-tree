import Foundation
import HTMLNIO
import Hummingbird
import HTTPTypes
import NIOCore
import ShapeTreeWebAuth
import ShapeTreeWebCore

enum ContentRoutes {
  static func register(
    on router: Router<AppRequestContext>,
    store: ContentStore
  ) {
    router.get("content/**") { request, context in
      try response(for: request, context: context, store: store, head: false)
    }
    router.head("content/**") { request, context in
      try response(for: request, context: context, store: store, head: true)
    }
  }

  private static func response(
    for request: Request,
    context: AppRequestContext,
    store: ContentStore,
    head: Bool
  ) throws -> Response {
    guard let relative = relativeContentPath(from: request) else {
      throw HTTPError(.notFound)
    }

    if relative.hasSuffix(".wasm") {
      let nodePath = String(relative.dropLast(".wasm".count))
      return try wasmResponse(
        nodePath: nodePath,
        store: store,
        isAuthenticated: context.identity != nil,
        head: head
      )
    }

    if relative.hasSuffix(".css") {
      guard store.canViewFile(
        relativePath: relative,
        isAuthenticated: context.identity != nil
      ) else {
        throw HTTPError(.notFound)
      }
      return try staticFileResponse(
        relativePath: relative,
        store: store,
        contentType: "text/css; charset=utf-8",
        head: head
      )
    }

    guard wantsHTMLDocument(request) else {
      throw HTTPError(.notFound)
    }

    if head {
      return Response(
        status: .ok,
        headers: [.contentType: "text/html; charset=utf-8"],
        body: .init(byteBuffer: ByteBuffer())
      )
    }
    return WebPages.shell(store: store).makeHTMLResponse()
  }

  private static func wasmResponse(
    nodePath: String,
    store: ContentStore,
    isAuthenticated: Bool,
    head: Bool
  ) throws -> Response {
    guard store.canView(path: nodePath, isAuthenticated: isAuthenticated),
      let url = store.wasmURL(forPath: nodePath)
    else {
      throw HTTPError(.notFound)
    }

    if head {
      return Response(
        status: .ok,
        headers: [
          .contentType: "application/wasm",
          .cacheControl: "no-cache",
        ],
        body: .init(byteBuffer: ByteBuffer())
      )
    }

    let bytes = try Data(contentsOf: url)
    guard !bytes.isEmpty else { throw HTTPError(.notFound) }
    return Response(
      status: .ok,
      headers: [
        .contentType: "application/wasm",
        .cacheControl: "no-cache",
      ],
      body: .init(byteBuffer: ByteBuffer(bytes: bytes))
    )
  }

  private static func staticFileResponse(
    relativePath: String,
    store: ContentStore,
    contentType: String,
    head: Bool
  ) throws -> Response {
    guard let url = store.resolveFile(relativePath: relativePath) else {
      throw HTTPError(.notFound)
    }
    if head {
      return Response(
        status: .ok,
        headers: [.contentType: contentType],
        body: .init(byteBuffer: ByteBuffer())
      )
    }
    let bytes = try Data(contentsOf: url)
    return Response(
      status: .ok,
      headers: [.contentType: contentType],
      body: .init(byteBuffer: ByteBuffer(bytes: bytes))
    )
  }

  static func relativeContentPath(from request: Request) -> String? {
    guard let path = request.uri.path.removingPercentEncoding else { return nil }
    let prefix = "/content/"
    guard path.hasPrefix(prefix) else { return nil }
    let relative = String(path.dropFirst(prefix.count))
    guard !relative.isEmpty, !relative.contains("..") else { return nil }
    return relative
  }

  private static let secFetchDest = HTTPField.Name("Sec-Fetch-Dest")!

  static func wantsHTMLDocument(_ request: Request) -> Bool {
    if request.headers[secFetchDest] == "document" { return true }
    if let accept = request.headers[.accept], accept.contains("text/html") { return true }
    return false
  }
}
