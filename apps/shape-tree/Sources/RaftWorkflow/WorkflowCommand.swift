import Foundation

/// Commands replicated through Raft. Each committed entry mutates `WorkflowStateMachine`.
public enum WorkflowCommand: Codable, Sendable, Equatable {
  case saveStep(workflowID: String, stepKey: String, data: Data)
  case resetWorkflow(workflowID: String)
}

public enum WorkflowCodec {
  public static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }()

  public static let decoder = JSONDecoder()

  public static func encode(_ command: WorkflowCommand) throws -> Data {
    try encoder.encode(command)
  }

  public static func decode(from data: Data) throws -> WorkflowCommand {
    try decoder.decode(WorkflowCommand.self, from: data)
  }
}
