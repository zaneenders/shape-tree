import Foundation
import HTTPTypes
import OpenAPIRuntime
import ShapeTreeClient

struct ShapeTreeAutoMintBearer: ClientMiddleware {

  let keyStore: ShapeTreeKeyStore
  let ttlSeconds: TimeInterval

  init(keyStore: ShapeTreeKeyStore, ttlSeconds: TimeInterval = 900) {
    self.keyStore = keyStore
    self.ttlSeconds = ttlSeconds
  }

  func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let token = try await MainActor.run {
      try keyStore.mintES256JWT(ttl: ttlSeconds)
    }
    var request = request
    request.headerFields[.authorization] = "Bearer \(token)"
    return try await next(request, body, baseURL)
  }
}
