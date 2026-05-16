import Foundation
import ScribeCore
import ShapeTreeClient

// MARK: - Scribe transcript → CompletionStreamEvent

enum CompletionStreamTranscriptMapping {

  static func line(for event: TranscriptEvent) -> Components.Schemas.CompletionStreamEvent {
    switch event {
    case .enterAssistantSection(let section, let previous):
      return Components.Schemas.CompletionStreamEvent(
        kind: .section_enter,
        stream_section: schemaSection(section),
        previous_stream_section: previous.map(schemaSection)
      )

    case .appendAssistantText(let section, let text):
      return Components.Schemas.CompletionStreamEvent(
        kind: .assistant_delta,
        stream_section: schemaSection(section),
        text: text
      )

    case .finalizeAssistantStream:
      return Components.Schemas.CompletionStreamEvent(kind: .finalize_assistant)

    case .emptyAssistantTurn:
      return Components.Schemas.CompletionStreamEvent(kind: .empty_turn)

    case .usage(let usage, let tokensPerSecond):
      return Components.Schemas.CompletionStreamEvent(
        kind: .usage,
        prompt_tokens: usage.promptTokens,
        completion_tokens: usage.completionTokens,
        total_tokens: usage.totalTokens,
        tokens_per_second: tokensPerSecond
      )

    case .blankLine:
      return Components.Schemas.CompletionStreamEvent(kind: .blank_line)

    case .toolRoundHeader(let round, toolNames: let names):
      return Components.Schemas.CompletionStreamEvent(
        kind: .tool_round,
        round: round,
        tool_names: names
      )

    case .toolInvocation(let name, let arguments, let output):
      return Components.Schemas.CompletionStreamEvent(
        kind: .tool_invocation,
        tool_name: name,
        tool_arguments: arguments,
        tool_output: output
      )

    case .skippedUnreadableStreamLine:
      return Components.Schemas.CompletionStreamEvent(kind: .skipped_line)

    case .harnessError(let error):
      return Components.Schemas.CompletionStreamEvent(
        kind: .harness_error,
        harness_error_message: error.localizedDescription
      )

    case .turnInterrupted:
      return Components.Schemas.CompletionStreamEvent(kind: .turn_interrupted)

    case .userSubmitted:
      return Components.Schemas.CompletionStreamEvent(kind: .blank_line)

    case .turnComplete:
      return Components.Schemas.CompletionStreamEvent(kind: .finalize_assistant)
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
