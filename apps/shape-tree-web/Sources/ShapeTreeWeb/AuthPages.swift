import Foundation
import Hummingbird
import NIOCore
import ShapeTreeWebAuth

struct AuthPages: Sendable {
  private let styles: String
  private let bootstrapScript: String

  init(styles: String, bootstrapScript: String) {
    self.styles = styles
    self.bootstrapScript = bootstrapScript
  }

  func checkEmail() -> Response {
    shellHTML(page: "check-email", next: "/", token: "")
  }

  func verify(token: String?, next: String?) -> Response {
    shellHTML(page: "verify", next: normalizedNext(next), token: token ?? "")
  }

  private func normalizedNext(_ raw: String?) -> String {
    raw.flatMap { AuthEmail.normalizedWasmNextPath($0) } ?? "/"
  }

  private func shellHTML(page: String, next: String, token: String) -> Response {
    let props: [String: String] = ["page": page, "next": next, "token": token]
    let propsData = (try? JSONSerialization.data(withJSONObject: props)) ?? Data()
    let propsJSON = String(data: propsData, encoding: .utf8) ?? "{}"
    let html = WebAssets.indexHTML(
      title: "Sign in",
      styles: styles,
      bootstrapScript: bootstrapScript,
      propsJSON: propsJSON
    )
    return Response(
      status: .ok,
      headers: [.contentType: "text/html; charset=utf-8"],
      body: .init(byteBuffer: ByteBuffer(string: html))
    )
  }
}
