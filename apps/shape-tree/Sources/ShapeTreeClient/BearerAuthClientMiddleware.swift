import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Injects `Authorization: Bearer …` on every OpenAPI client request.
public struct BearerAuthClientMiddleware: ClientMiddleware {
  public let bearerToken: String

  public init(bearerToken raw: String) {
    self.bearerToken = ShapeTreeAPIClientMiddleware.normalizedBearerJWT(raw)
  }

  public func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var request = request
    request.headerFields[.authorization] = "Bearer \(bearerToken)"
    return try await next(request, body, baseURL)
  }
}
