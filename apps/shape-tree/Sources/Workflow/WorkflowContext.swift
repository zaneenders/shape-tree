import Foundation
import Logging
import Synchronization

public struct WorkflowContext: Sendable, ~Copyable {
  public let id: String
  private let store: any StepStore
  private let log: Logger
  private let stepCounter: Mutex<Int> = Mutex(0)

  public init(id: String = UUID().uuidString, store: any StepStore, log: Logger = Logger(label: "workflow")) {
    self.id = id
    self.store = store
    self.log = log
  }

  public func step<T: Codable & Sendable>(body: () async throws -> T) async throws -> T {
    let key = stepCounter.withLock { count in
      count += 1
      return String(count)
    }

    if let cached = try await store.load(workflowID: id, stepKey: key) {
      log.debug("event=workflow.step.cached workflowID=\(id) step=\(key)")
      return try JSONDecoder().decode(T.self, from: cached)
    }

    log.debug("event=workflow.step.run workflowID=\(id) step=\(key)")
    let value = try await body()
    try await store.save(workflowID: id, stepKey: key, data: JSONEncoder().encode(value))
    log.debug("event=workflow.step.saved workflowID=\(id) step=\(key)")
    return value
  }
}
