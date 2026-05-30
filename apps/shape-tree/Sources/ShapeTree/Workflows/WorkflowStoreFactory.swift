import Foundation
import Logging
import RaftWorkflow

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

    var endpoints: [WorkflowEndpoint] = []
    endpoints.reserveCapacity(raftEndpointStrings.count)

    for value in raftEndpointStrings {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      do {
        let parsed = try EndpointAddressParser.parse(trimmed, defaultHost: "127.0.0.1")
        endpoints.append(WorkflowEndpoint(host: parsed.host, port: parsed.port))
      } catch {
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
}
