import Foundation
import Logging
import SystemPackage
import Testing
import _NIOFileSystem

@testable import Workflow

@Suite struct WorkflowTests {

  @Test func stepRunsOnce() async throws {
    try await withWorkflowStore { store, _ in
      var callCount = 0
      let ctx = WorkflowContext(store: store)
      let a = try await ctx.step {
        callCount += 1
        return 42
      }
      let b = try await ctx.step {
        callCount += 1
        return 99
      }
      #expect(a == 42)
      #expect(b == 99)
      #expect(callCount == 2)
    }
  }

  @Test func replayReturnsCachedValue() async throws {
    try await withWorkflowStore { store, _ in
      var callCount = 0
      let ctx1 = WorkflowContext(store: store)
      _ = try await ctx1.step {
        callCount += 1
        return "hello"
      }

      let ctx2 = WorkflowContext(id: ctx1.id, store: store)
      let result = try await ctx2.step {
        callCount += 1
        return "world"
      }

      #expect(result == "hello")
      #expect(callCount == 1)
    }
  }

  @Test func loopStepsCacheSequentially() async throws {
    try await withWorkflowStore { store, dir in
      let ctx = WorkflowContext(store: store)
      var results: [Int] = []
      for i in 0..<3 {
        let v = try await ctx.step { i * 10 }
        results.append(v)
      }
      #expect(results == [0, 10, 20])

      let taskDir = dir.appending(ctx.id)
      let handle = try await FileSystem.shared.openDirectory(atPath: taskDir, options: .init())
      var names: Set<String> = []
      for try await entry in handle.listContents(recursive: false) { names.insert(entry.name.string) }
      try await handle.close()
      #expect(names.contains("1.json"))
      #expect(names.contains("2.json"))
      #expect(names.contains("3.json"))
    }
  }

  @Test func resetClearsStepsForWorkflow() async throws {
    try await withWorkflowStore { store, _ in
      let ctx1 = WorkflowContext(store: store)
      _ = try await ctx1.step { "cached" }

      try await store.reset(workflowID: ctx1.id)

      let ctx2 = WorkflowContext(id: ctx1.id, store: store)
      var callCount = 0
      let result = try await ctx2.step {
        callCount += 1
        return "fresh"
      }
      #expect(result == "fresh")
      #expect(callCount == 1)
    }
  }

  @Test func resetIsNoOpWhenWorkflowAbsent() async throws {
    try await withWorkflowStore { store, _ in
      // Should not throw for a workflow ID that was never run.
      try await store.reset(workflowID: "nonexistent-workflow")
    }
  }

  @Test func resetDoesNotAffectOtherWorkflows() async throws {
    try await withWorkflowStore { store, _ in
      let ctxA = WorkflowContext(store: store)
      let ctxB = WorkflowContext(store: store)
      _ = try await ctxA.step { "a-value" }
      _ = try await ctxB.step { "b-value" }

      try await store.reset(workflowID: ctxA.id)

      // ctxB's cache is untouched
      let ctxBReplay = WorkflowContext(id: ctxB.id, store: store)
      var callCount = 0
      let result = try await ctxBReplay.step {
        callCount += 1
        return "b-replaced"
      }
      #expect(result == "b-value")
      #expect(callCount == 0)
    }
  }

  @Test func persistsAcrossContexts() async throws {
    try await withWorkflowStore { store, _ in
      let ctx1 = WorkflowContext(store: store)
      _ = try await ctx1.step { 1 }
      _ = try await ctx1.step { 2 }

      let ctx2 = WorkflowContext(id: ctx1.id, store: store)
      let a = try await ctx2.step { 999 }
      let b = try await ctx2.step { 999 }
      #expect(a == 1)
      #expect(b == 2)
    }
  }
}

private func withWorkflowStore<R>(
  _ body: (FileStepStore, FilePath) async throws -> R
) async throws -> R {
  try await FileSystem.shared.withTemporaryDirectory { _, path in
    let dir = path.appending("/tmp/workflow-tests-\(UUID().uuidString)")
    let store = try await FileStepStore(root: dir)
    let result = try await body(store, dir)
    return result
  }
}

// MARK: - WorkflowWorker tests

@Suite struct WorkflowWorkerTests {

  @Test func runsPerformForEnqueuedKey() async throws {
    let tracker = CallTracker()
    let worker = WorkflowWorker(log: Logger(label: "test")) { key in
      await tracker.record(key)
    }

    await worker.enqueue(key: "a")
    try await waitUntil { await tracker.calls.count >= 1 }
    #expect(await tracker.calls == ["a"])
  }

  @Test func deduplicatesInFlightRequests() async throws {
    let tracker = CallTracker()
    let gate = Gate()
    let worker = WorkflowWorker(log: Logger(label: "test")) { _ in
      await gate.wait()
      await tracker.record("x")
    }

    await worker.enqueue(key: "x")
    await worker.enqueue(key: "x")  // deduplicated: "x" is still in-flight
    await gate.open()

    try await waitUntil { await tracker.calls.count >= 1 }
    #expect(await tracker.calls.count == 1)
  }

  @Test func differentKeysRunIndependently() async throws {
    let tracker = CallTracker()
    let worker = WorkflowWorker(log: Logger(label: "test")) { key in
      await tracker.record(key)
    }

    await worker.enqueue(key: "a")
    await worker.enqueue(key: "b")
    try await waitUntil { await tracker.calls.count >= 2 }
    #expect(Set(await tracker.calls) == ["a", "b"])
  }

  @Test func reEnqueueableAfterCompletion() async throws {
    let tracker = CallTracker()
    let worker = WorkflowWorker(log: Logger(label: "test")) { key in
      await tracker.record(key)
    }

    await worker.enqueue(key: "z")
    try await waitUntil { await tracker.calls.count >= 1 }
    await worker.enqueue(key: "z")
    try await waitUntil { await tracker.calls.count >= 2 }
    #expect(await tracker.calls.count == 2)
  }

  @Test func survivesErrorInPerform() async throws {
    let tracker = CallTracker()
    let failOnce = FailOnce()

    let worker = WorkflowWorker(log: Logger(label: "test")) { key in
      if await failOnce.check() {
        throw WorkerTestError.boom
      }
      await tracker.record(key)
    }

    await worker.enqueue(key: "a")
    // 50ms is ample for the task to throw and have the actor clean up inFlight.
    try await Task.sleep(for: .milliseconds(50))

    await worker.enqueue(key: "a")
    try await waitUntil { await tracker.calls.count >= 1 }
    #expect(await tracker.calls.count == 1)
  }
}

// MARK: - Helpers

private actor CallTracker {
  var calls: [String] = []
  func record(_ key: String) { calls.append(key) }
}

private actor Gate {
  private var waiter: CheckedContinuation<Void, Never>?
  private var isOpen = false

  func wait() async {
    if isOpen { return }
    await withCheckedContinuation { self.waiter = $0 }
  }

  func open() {
    isOpen = true
    waiter?.resume()
    waiter = nil
  }
}

private actor FailOnce {
  private var remaining = 1
  func check() -> Bool {
    if remaining > 0 {
      remaining -= 1
      return true
    }
    return false
  }
}

private enum WorkerTestError: Error { case boom }

private func waitUntil(
  timeout: Duration = .seconds(5),
  _ condition: () async -> Bool
) async throws {
  let deadline = ContinuousClock.now + timeout
  while ContinuousClock.now < deadline {
    if await condition() { return }
    try await Task.sleep(for: .milliseconds(10))
  }
  throw TimedOutError()
}

private struct TimedOutError: Error, CustomStringConvertible {
  var description: String { "Timed out waiting for condition" }
}
