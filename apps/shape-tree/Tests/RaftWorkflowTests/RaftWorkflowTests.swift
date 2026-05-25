import Darwin
import Foundation
import Raft
import Testing
import Workflow

@testable import RaftWorkflow

@Suite struct WorkflowStateMachineTests {
  @Test func saveAndLoadStep() async throws {
    let machine = WorkflowStateMachine()
    let entry = LogEntry(
      term: 1,
      command: try WorkflowCodec.encode(.saveStep(workflowID: "wf-1", stepKey: "1", data: Data("hello".utf8))))

    let result = try await machine.apply(entry: entry)
    #expect(result == .saved)

    let loaded = await machine.load(workflowID: "wf-1", stepKey: "1")
    #expect(loaded == Data("hello".utf8))
  }

  @Test func resetRemovesWorkflow() async throws {
    let machine = WorkflowStateMachine()
    _ = try await machine.apply(
      entry: LogEntry(
        term: 1,
        command: try WorkflowCodec.encode(.saveStep(workflowID: "wf-1", stepKey: "1", data: Data("x".utf8)))))

    _ = try await machine.apply(
      entry: LogEntry(
        term: 1,
        command: try WorkflowCodec.encode(.resetWorkflow(workflowID: "wf-1"))))

    let loaded = await machine.load(workflowID: "wf-1", stepKey: "1")
    #expect(loaded == nil)
  }

  @Test func snapshotRoundTrip() async throws {
    let machine = WorkflowStateMachine()
    _ = try await machine.apply(
      entry: LogEntry(
        term: 1,
        command: try WorkflowCodec.encode(.saveStep(workflowID: "wf-1", stepKey: "1", data: Data("a".utf8)))))

    let snapshot = try await machine.snapshot()
    let restored = WorkflowStateMachine()
    try await restored.restore(from: snapshot)

    let loaded = await restored.load(workflowID: "wf-1", stepKey: "1")
    #expect(loaded == Data("a".utf8))
  }
}

@Suite(.serialized)
struct RaftWorkflowClusterTests {
  @Test func replicatedStepVisibleOnFollower() async throws {
    try await withRaftWorkflowCluster { endpoints in
      let store = RaftStepStore(endpoints: endpoints)

      try await store.save(
        workflowID: "daily-summary-25-05-24",
        stepKey: "1",
        data: Data("cached".utf8))

      let loaded = try await store.load(workflowID: "daily-summary-25-05-24", stepKey: "1")
      #expect(loaded == Data("cached".utf8))

      let followerClient = RaftWorkflowClient(endpoints: [endpoints[2]])
      let onFollower = try await followerClient.load(workflowID: "daily-summary-25-05-24", stepKey: "1")
      #expect(onFollower == Data("cached".utf8))
    }
  }

  @Test func workflowContextReplayUsesRaftStore() async throws {
    try await withRaftWorkflowCluster { endpoints in
      let store = RaftStepStore(endpoints: endpoints)

      var callCount = 0
      let ctx1 = WorkflowContext(id: "wf-replay", store: store)
      let first = try await ctx1.step {
        callCount += 1
        return "expensive-result"
      }

      let ctx2 = WorkflowContext(id: "wf-replay", store: store)
      let replay = try await ctx2.step {
        callCount += 1
        return "different"
      }

      #expect(first == "expensive-result")
      #expect(replay == "expensive-result")
      #expect(callCount == 1)
    }
  }

  @Test func resetClearsReplicatedSteps() async throws {
    try await withRaftWorkflowCluster { endpoints in
      let store = RaftStepStore(endpoints: endpoints)

      let ctx = WorkflowContext(id: "wf-reset", store: store)
      _ = try await ctx.step { "keep-me" }

      try await store.reset(workflowID: "wf-reset")

      var callCount = 0
      let fresh = try await ctx.step {
        callCount += 1
        return "new-value"
      }

      #expect(fresh == "new-value")
      #expect(callCount == 1)
    }
  }
}

private func withRaftWorkflowCluster<R>(
  _ body: ([RaftWorkflowEndpoint]) async throws -> R
) async throws -> R {
  let basePort = 19_000 + Int.random(in: 0..<100) * 10
  let ports = [basePort, basePort + 1, basePort + 2]
  let endpoints = ports.map { RaftWorkflowEndpoint(host: "127.0.0.1", port: $0) }

  let binary = try locateRaftWorkflowNodeBinary()
  let storeRoot = FileManager.default.temporaryDirectory
    .appendingPathComponent("raft-workflow-test-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: storeRoot, withIntermediateDirectories: true)

  var processes: [Process] = []
  defer {
    for process in processes where process.isRunning {
      process.terminate()
    }
    try? FileManager.default.removeItem(at: storeRoot)
  }

  for (index, port) in ports.enumerated() {
    let peerArgs = ports.filter { $0 != port }.map { String($0) }
    var arguments = [
      "--port", String(port),
      "--no-wait-for-peers",
      "--election-timeout-ms", "200-400",
      "--store-dir", storeRoot.appendingPathComponent("node-\(index)").path,
    ]
    for peerPort in peerArgs {
      arguments.append(contentsOf: ["--peer", String(peerPort)])
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: binary)
    process.arguments = arguments
    let stderrPipe = Pipe()
    process.standardError = stderrPipe
    try process.run()
    processes.append(process)
  }

  try await waitForPorts(ports)
  try await waitForLeader(endpoints: endpoints)

  return try await body(endpoints)
}

private func locateRaftWorkflowNodeBinary() throws -> String {
  let cwd = FileManager.default.currentDirectoryPath
  let candidates = [
    "\(cwd)/.build/debug/raft-workflow-node",
    "\(cwd)/.build/arm64-apple-macosx/debug/raft-workflow-node",
  ]
  for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
    return candidate
  }
  throw ClusterTestError.missingBinary
}

private func waitForLeader(
  endpoints: [RaftWorkflowEndpoint],
  timeout: Duration = .seconds(10)
) async throws {
  let deadline = ContinuousClock.now + timeout
  let client = RaftWorkflowClient(endpoints: endpoints)

  while ContinuousClock.now < deadline {
    do {
      try await client.propose(
        .saveStep(workflowID: "__probe__", stepKey: "0", data: Data("ok".utf8)))
      return
    } catch RaftWorkflowError.notLeader {
      try await Task.sleep(for: .milliseconds(100))
    }
  }

  throw ClusterTestError.timeout
}

private func waitForPorts(_ ports: [Int], timeout: Duration = .seconds(15)) async throws {
  let deadline = ContinuousClock.now + timeout
  while ContinuousClock.now < deadline {
    if ports.allSatisfy(isPortOpen) {
      try await Task.sleep(for: .milliseconds(200))
      return
    }
    try await Task.sleep(for: .milliseconds(100))
  }
  throw ClusterTestError.timeout
}

private func isPortOpen(_ port: Int) -> Bool {
  let socket = socket(AF_INET, SOCK_STREAM, 0)
  guard socket >= 0 else { return false }
  defer { close(socket) }

  var addr = sockaddr_in()
  addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  addr.sin_family = sa_family_t(AF_INET)
  addr.sin_port = in_port_t(UInt16(port).bigEndian)
  inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

  let result = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  return result == 0
}

private enum ClusterTestError: Error, CustomStringConvertible {
  case missingBinary
  case timeout

  var description: String {
    switch self {
    case .missingBinary:
      "Build raft-workflow-node first: swift build --product raft-workflow-node"
    case .timeout:
      "Timed out waiting for raft-workflow-node processes."
    }
  }
}
