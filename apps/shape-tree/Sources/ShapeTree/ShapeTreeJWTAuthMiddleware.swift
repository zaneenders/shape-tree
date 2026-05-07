import HTTPTypes
import Hummingbird
import JWTKit

/// Validates `Authorization: Bearer <jwt>` using the server's configured HMAC secret.
struct ShapeTreeJWTAuthMiddleware: MiddlewareProtocol {
  typealias Input = Request
  typealias Output = Response
  typealias Context = BasicRequestContext

  private let keys: JWTKeyCollection

  init(keys: JWTKeyCollection) {
    self.keys = keys
  }

  func handle(
    _ request: Input,
    context: Context,
    next: @concurrent (Input, Context) async throws -> Output
  ) async throws -> Output {
    context.logger.info(
      "event=http.request method=\(request.method) path=\(request.head.path ?? "")"
    )

    guard let authHeader = request.headers[.authorization] else {
      throw HTTPError(.unauthorized, message: "Missing Authorization header")
    }

    guard authHeader.hasPrefix("Bearer ") else {
      throw HTTPError(.unauthorized, message: "Invalid Authorization header format")
    }

    let token = String(authHeader.dropFirst(7))

    do {
      _ = try await keys.verify(token, as: ShapeTreeJWTPayload.self)
    } catch let error as JWTError {
      if error.errorType == JWTError.ErrorType.claimVerificationFailure {
        if error.failedClaim is ExpirationClaim {
          throw HTTPError(.unauthorized, message: "JWT token expired")
        }
      }
      context.logger.debug("JWT verification failed: \(String(describing: error))")
      throw HTTPError(.unauthorized, message: "Invalid or expired JWT")
    } catch {
      context.logger.debug("JWT verification failed: \(String(describing: error))")
      throw HTTPError(.unauthorized, message: "Invalid or expired JWT")
    }

    return try await next(request, context)
  }
}
