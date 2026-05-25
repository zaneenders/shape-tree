import Foundation
import Workflow

/// `StepStore` backed by a replicated Raft cluster.
///
/// Point this at any workflow node address; writes find the leader automatically.
public struct RaftStepStore: StepStore, Sendable {
  private let client: RaftWorkflowClient

  public init(endpoints: [RaftWorkflowEndpoint]) {
    self.client = RaftWorkflowClient(endpoints: endpoints)
  }

  public init(client: RaftWorkflowClient) {
    self.client = client
  }

  public func load(workflowID: String, stepKey: String) async throws -> Data? {
    try await client.load(workflowID: workflowID, stepKey: stepKey)
  }

  public func save(workflowID: String, stepKey: String, data: Data) async throws {
    try await client.propose(.saveStep(workflowID: workflowID, stepKey: stepKey, data: data))
  }

  public func reset(workflowID: String) async throws {
    try await client.propose(.resetWorkflow(workflowID: workflowID))
  }
}
