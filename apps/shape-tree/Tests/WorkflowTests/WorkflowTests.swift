import Foundation
import Logging
import RaftWorkflow
import Testing

@testable import Workflow

@Suite(.serialized)
struct WorkflowTests {

  @Test func stepRunsOnce() async throws {
    try await withWorkflowStore { store, _ in
      var callCount = 0
      let ctx = WorkflowContext(store: store)
      let a = try await ctx.step("a") {
        callCount += 1
        return 42
      }
      let b = try await ctx.step("b") {
        callCount += 1
        return 99
      }
      #expect(a.value == 42)
      #expect(b.value == 99)
      #expect(callCount == 2)
    }
  }

  @Test func replayReturnsCachedValue() async throws {
    try await withWorkflowStore { store, _ in
      var callCount = 0
      let ctx1 = WorkflowContext(store: store)
      _ = try await ctx1.step("greeting") {
        callCount += 1
        return "hello"
      }

      let ctx2 = WorkflowContext(id: ctx1.id, store: store)
      let result = try await ctx2.step("greeting") {
        callCount += 1
        return "world"
      }

      #expect(result.value == "hello")
      #expect(result.fromCache)
      #expect(callCount == 1)
    }
  }

  @Test func loopStepsCacheSequentially() async throws {
    try await withWorkflowStore { store, dir in
      let ctx = WorkflowContext(store: store)
      var results: [Int] = []
      for i in 0..<3 {
        let outcome = try await ctx.step("step-\(i)") { i * 10 }
        results.append(outcome.value)
      }
      #expect(results == [0, 10, 20])

      let taskDir = dir.appendingPathComponent(ctx.id)
      let names = Set(try FileManager.default.contentsOfDirectory(atPath: taskDir.path))
      #expect(names.contains("step-0"))
      #expect(names.contains("step-1"))
      #expect(names.contains("step-2"))
    }
  }

  @Test func resetClearsStepsForWorkflow() async throws {
    try await withWorkflowStore { store, _ in
      let ctx1 = WorkflowContext(store: store)
      _ = try await ctx1.step("only") { "cached" }

      try await store.reset(workflowID: ctx1.id)

      let ctx2 = WorkflowContext(id: ctx1.id, store: store)
      var callCount = 0
      let result = try await ctx2.step("only") {
        callCount += 1
        return "fresh"
      }
      #expect(result.value == "fresh")
      #expect(callCount == 1)
    }
  }

  @Test func resetIsNoOpWhenWorkflowAbsent() async throws {
    try await withWorkflowStore { store, _ in
      try await store.reset(workflowID: "nonexistent-workflow")
    }
  }

  @Test func resetDoesNotAffectOtherWorkflows() async throws {
    try await withWorkflowStore { store, _ in
      let ctxA = WorkflowContext(store: store)
      let ctxB = WorkflowContext(store: store)
      _ = try await ctxA.step("value") { "a-value" }
      _ = try await ctxB.step("value") { "b-value" }

      try await store.reset(workflowID: ctxA.id)

      let ctxBReplay = WorkflowContext(id: ctxB.id, store: store)
      var callCount = 0
      let result = try await ctxBReplay.step("value") {
        callCount += 1
        return "b-replaced"
      }
      #expect(result.value == "b-value")
      #expect(callCount == 0)
    }
  }

  @Test func persistsAcrossContexts() async throws {
    try await withWorkflowStore { store, _ in
      let ctx1 = WorkflowContext(store: store)
      _ = try await ctx1.step("first") { 1 }
      _ = try await ctx1.step("second") { 2 }

      let ctx2 = WorkflowContext(id: ctx1.id, store: store)
      let a = try await ctx2.step("first") { 999 }
      let b = try await ctx2.step("second") { 999 }
      #expect(a.value == 1)
      #expect(b.value == 2)
    }
  }
}

private func withWorkflowStore<R>(
  _ body: (FileStepStore, URL) async throws -> R
) async throws -> R {
  let dir = URL(fileURLWithPath: "/tmp/shape-tree-workflow-tests-\(UUID().uuidString)", isDirectory: true)
  defer { try? FileManager.default.removeItem(at: dir) }
  let store = try FileStepStore(directory: dir)
  return try await body(store, dir)
}
