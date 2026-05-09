import Foundation
import OpenAPIRuntime

extension Operations.runCompletionStream.Output.Ok {

  /// Decodes JSON Lines from a successful streamed completion response into typed events.
  public func decodedCompletionEvents() throws -> some AsyncSequence<
    Components.Schemas.CompletionStreamEvent, Swift.Error
  > {
    try body.application_jsonl.asDecodedJSONLines(
      of: Components.Schemas.CompletionStreamEvent.self)
  }
}
