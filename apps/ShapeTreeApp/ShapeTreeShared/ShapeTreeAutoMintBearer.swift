import Foundation
import HTTPTypes
import OpenAPIRuntime
import ShapeTreeClient

/// `ClientMiddleware` that mints a fresh ES256 JWT from the on-device
/// `ShapeTreeKeyStore` on every outbound request (auth.md, "App changes").
///
/// Caching is deliberately avoided here — minting is local and cheap, the
/// TTL is short (15 minutes), and per-request minting means a key
/// regeneration in Settings takes effect on the very next call without any
/// invalidation plumbing.
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
