import Foundation
import Logging
import ShapeTreeClient

extension ShapeTreeHandler {

  /// Single source of truth for the JSON body of every error response.
  static func errorBody(_ message: String) -> Components.Schemas.HTTPErrorResponse {
    .init(error: .init(message: message))
  }

  /// Logs `event` and the underlying error, then returns the public 500 body. All non-domain
  /// failures funnel through this so the operator sees a structured log line for every 500.
  func internalErrorBody(event: String, _ error: Error, public publicMessage: String)
    -> Components.Schemas.HTTPErrorResponse
  {
    log.error("event=\(event) error=\(error.localizedDescription)")
    return Self.errorBody(publicMessage)
  }
}
