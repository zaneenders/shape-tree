import Foundation
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
