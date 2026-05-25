import Foundation
import Raft

public enum WorkflowApplyResult: Sendable, Equatable {
  case saved
  case reset
  case ignoredDuplicateSave
}

/// Deterministic state machine driven by committed Raft log entries.
///
/// Raft owns ordering and durability; this type owns workflow step data.
public actor WorkflowStateMachine {
  private var steps: [String: [String: Data]] = [:]

  public init() {}

  public func apply(entry: LogEntry) throws -> WorkflowApplyResult {
    let command = try WorkflowCodec.decode(from: entry.command)
    switch command {
    case .saveStep(let workflowID, let stepKey, let data):
      var workflow = steps[workflowID, default: [:]]
      if workflow[stepKey] != nil {
        return .ignoredDuplicateSave
      }
      workflow[stepKey] = data
      steps[workflowID] = workflow
      return .saved

    case .resetWorkflow(let workflowID):
      steps.removeValue(forKey: workflowID)
      return .reset
    }
  }

  public func load(workflowID: String, stepKey: String) -> Data? {
    steps[workflowID]?[stepKey]
  }

  public func snapshot() throws -> Data {
    try WorkflowCodec.encoder.encode(steps)
  }

  public func restore(from data: Data) throws {
    steps = try WorkflowCodec.decoder.decode([String: [String: Data]].self, from: data)
  }
}
