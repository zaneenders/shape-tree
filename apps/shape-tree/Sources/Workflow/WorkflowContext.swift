import Foundation
import Synchronization

public final class WorkflowContext: Sendable {
  public let id: String
  private let store: FileStepStore
  private let stepCounter: Mutex<Int> = Mutex(0)

  public init(id: String = UUID().uuidString, store: FileStepStore) {
    self.id = id
    self.store = store
  }

  public func step<T: Codable & Sendable>(body: () async throws -> T) async throws -> T {
    let key = stepCounter.withLock { count in
      count += 1
      return String(count)
    }

    if let cached = try await store.load(workflowID: id, stepKey: key) {
      return try JSONDecoder().decode(T.self, from: cached)
    }
    let value = try await body()
    try await store.save(workflowID: id, stepKey: key, data: JSONEncoder().encode(value))
    return value
  }
}
