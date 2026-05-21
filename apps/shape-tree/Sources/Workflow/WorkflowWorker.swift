import Logging

public actor WorkflowWorker {
  private let perform: @Sendable (String) async throws -> Void
  private let log: Logger
  private var inFlight: Set<String> = []

  public init(log: Logger, perform: @escaping @Sendable (String) async throws -> Void) {
    self.perform = perform
    self.log = log
  }

  public func enqueue(key: String) {
    guard !inFlight.contains(key) else {
      log.debug("event=worker.skip key=\(key) reason=in-flight")
      return
    }
    inFlight.insert(key)
    Task {
      await run(key: key)
    }
  }

  private func run(key: String) async {
    defer { inFlight.remove(key) }
    do {
      try await perform(key)
      log.info("event=worker.complete key=\(key)")
    } catch {
      log.error("event=worker.failed key=\(key) error=\(error)")
    }
  }
}
