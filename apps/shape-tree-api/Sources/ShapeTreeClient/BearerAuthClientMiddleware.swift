import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Sets `Authorization: Bearer <token>` on every outgoing request.
///
/// Two factories share one middleware:
/// - ``init(bearerToken:)`` — a static token (tests, scripts).
/// - ``init(tokenProvider:)`` — an async closure that mints a fresh token per request
///   (apps with per-device key material; replaces the previous `ShapeTreeAutoMintBearer`).
public struct BearerAuthClientMiddleware: ClientMiddleware {
  public typealias TokenProvider = @Sendable () async throws -> String

  let provider: TokenProvider

  public init(bearerToken raw: String) {
    let normalized = ShapeTreeAPIClientMiddleware.normalizedBearerJWT(raw)
    self.provider = { normalized }
  }

  public init(tokenProvider: @escaping TokenProvider) {
    self.provider = tokenProvider
  }

  public func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var request = request
    request.headerFields[.authorization] = "Bearer \(try await provider())"
    return try await next(request, body, baseURL)
  }
}
