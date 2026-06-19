import Foundation
import ScribeCore
import ShapeTreeClient

// MARK: - Scribe AgentEvent → CompletionStreamEvent

enum CompletionStreamTranscriptMapping {

  static func line(for event: AgentEvent) -> Components.Schemas.CompletionStreamEvent? {
    switch event {
    case .output(.sectionStarted(let section, let previous)):
      return Components.Schemas.CompletionStreamEvent(
        kind: .section_enter,
        stream_section: schemaSection(section),
        previous_stream_section: previous.map(schemaSection)
      )

    case .output(.text(let section, let text)):
      return Components.Schemas.CompletionStreamEvent(
        kind: .assistant_delta,
        stream_section: schemaSection(section),
        text: text
      )

    case .output(.finalized):
      return Components.Schemas.CompletionStreamEvent(kind: .finalize_assistant)

    case .output(.empty):
      return Components.Schemas.CompletionStreamEvent(kind: .empty_turn)

    case .lifecycle(.usage(let usage, let tokensPerSecond)):
      return Components.Schemas.CompletionStreamEvent(
        kind: .usage,
        prompt_tokens: usage.promptTokens,
        completion_tokens: usage.completionTokens,
        total_tokens: usage.totalTokens,
        tokens_per_second: tokensPerSecond
      )

    case .lifecycle(.error(let error)):
      return Components.Schemas.CompletionStreamEvent(
        kind: .harness_error,
        harness_error_message: error.errorDescription ?? String(describing: error)
      )

    case .lifecycle(.interrupted):
      return Components.Schemas.CompletionStreamEvent(kind: .turn_interrupted)

    case .lifecycle(.recovered):
      return Components.Schemas.CompletionStreamEvent(kind: .blank_line)

    case .tool(.invocation(let name, let arguments, let output)):
      return Components.Schemas.CompletionStreamEvent(
        kind: .tool_invocation,
        tool_name: name,
        tool_arguments: arguments,
        tool_output: output
      )

    case .tool(.warning):
      return nil

    case .boundary(.turnStart(let round)) where round > 1:
      return Components.Schemas.CompletionStreamEvent(
        kind: .tool_round,
        round: round,
        tool_names: []
      )

    case .boundary(.messageStart(role: .user, _)):
      return Components.Schemas.CompletionStreamEvent(kind: .blank_line)

    case .boundary:
      return nil
    }
  }

  static func schemaSection(_ section: AssistantStreamSection) -> Components.Schemas.CompletionStreamSection {
    switch section {
    case .reasoning: .reasoning
    case .answer: .answer
    }
  }

  static func outcome(_ outcome: TurnOutcome) -> Components.Schemas.CompletionStreamOutcome {
    switch outcome {
    case .completed:
      return .completed
    case .interrupted:
      return .interrupted
    case .toolRoundLimit:
      return .tool_round_limit
    }
  }

  static func toolRoundLimitRounds(_ outcome: TurnOutcome) -> Int? {
    if case .toolRoundLimit(let rounds) = outcome {
      return rounds
    }
    return nil
  }
}
