import Foundation

/// Persists workflow step outputs so a run can replay without re-executing side effects.
public protocol StepStore: Sendable {
  func load(workflowID: String, stepKey: String) async throws -> Data?
  func save(workflowID: String, stepKey: String, data: Data) async throws
  func reset(workflowID: String) async throws
}
