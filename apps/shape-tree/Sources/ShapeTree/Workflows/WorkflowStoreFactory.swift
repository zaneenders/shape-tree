import Foundation
import Logging
import RaftWorkflow
import Workflow

enum WorkflowStoreError: Error, CustomStringConvertible {
  case missingEndpoints
  case invalidEndpoint(String)

  var description: String {
    switch self {
    case .missingEndpoints:
      "workflow.raft.endpoints is required and must list at least one HOST:PORT workflow node."
    case .invalidEndpoint(let value):
      "Invalid workflow.raft.endpoints entry '\(value)'. Expected HOST:PORT or PORT."
    }
  }
}

enum WorkflowStoreFactory {
  static func make(
    raftEndpointStrings: [String],
    log: Logger
  ) throws -> any StepStore {
    guard !raftEndpointStrings.isEmpty else {
      throw WorkflowStoreError.missingEndpoints
    }

    var endpoints: [RaftWorkflowEndpoint] = []
    endpoints.reserveCapacity(raftEndpointStrings.count)

    for value in raftEndpointStrings {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      if let endpoint = parseRaftEndpoint(trimmed) {
        endpoints.append(endpoint)
      } else {
        throw WorkflowStoreError.invalidEndpoint(trimmed)
      }
    }

    guard !endpoints.isEmpty else {
      throw WorkflowStoreError.missingEndpoints
    }

    log.info(
      "event=workflow.store backend=raft endpoints=\(endpoints.map { "\($0.host):\($0.port)" }.joined(separator: ","))")
    return RaftStepStore(endpoints: endpoints)
  }

  private static func parseRaftEndpoint(_ value: String) -> RaftWorkflowEndpoint? {
    if value.contains(":") {
      let parts = value.split(separator: ":", maxSplits: 1)
      guard parts.count == 2, let port = Int(parts[1]) else { return nil }
      return RaftWorkflowEndpoint(host: String(parts[0]), port: port)
    }

    guard let port = Int(value) else { return nil }
    return RaftWorkflowEndpoint(host: "127.0.0.1", port: port)
  }
}
