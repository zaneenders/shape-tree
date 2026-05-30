import Darwin
import Foundation
import Raft
import RaftBlob
import RaftWorkflow
import Testing

@Suite struct WorkflowStateMachineTests {
  @Test func saveAndLoadStepRef() async throws {
    let machine = WorkflowStateMachine()
    let data = Data("hello".utf8)
    let hash = ContentHash.sha256(data)
    let entry = LogEntry(
      term: 1,
      command: try WorkflowCodec.encode(
        .saveStepRef(workflowID: "wf-1", stepKey: "1", hash: hash, byteCount: data.count)))

    let result = try await machine.apply(entry: entry)
    #expect(result == .saved)

    let loaded = await machine.stepRef(workflowID: "wf-1", stepKey: "1")
    #expect(loaded == StepRef(hash: hash, byteCount: data.count))
  }

  @Test func resetRemovesWorkflow() async throws {
    let machine = WorkflowStateMachine()
    let data = Data("x".utf8)
    let hash = ContentHash.sha256(data)
    _ = try await machine.apply(
      entry: LogEntry(
        term: 1,
        command: try WorkflowCodec.encode(
          .saveStepRef(workflowID: "wf-1", stepKey: "1", hash: hash, byteCount: data.count))))

    _ = try await machine.apply(
      entry: LogEntry(
        term: 1,
        command: try WorkflowCodec.encode(.resetWorkflow(workflowID: "wf-1"))))

    #expect(await machine.hasStep(workflowID: "wf-1", stepKey: "1") == false)
  }

  @Test func snapshotRoundTrip() async throws {
    let machine = WorkflowStateMachine()
    let data = Data("a".utf8)
    let hash = ContentHash.sha256(data)
    _ = try await machine.apply(
      entry: LogEntry(
        term: 1,
        command: try WorkflowCodec.encode(
          .saveStepRef(workflowID: "wf-1", stepKey: "1", hash: hash, byteCount: data.count))))

    let snapshot = try await machine.snapshot()
    let restored = WorkflowStateMachine()
    try await restored.restore(from: snapshot)

    let loaded = await restored.stepRef(workflowID: "wf-1", stepKey: "1")
    #expect(loaded == StepRef(hash: hash, byteCount: data.count))
  }
}

@Suite(.serialized)
struct RaftWorkflowClusterTests {
  @Test func replicatedStepVisibleOnFollower() async throws {
    try await withRaftWorkflowCluster { cluster in
      let store = RaftStepStore(endpoints: cluster.endpoints)

      try await store.save(
        workflowID: "daily-summary-25-05-24",
        stepKey: "1",
        data: Data("cached".utf8))

      let loaded = try await store.load(workflowID: "daily-summary-25-05-24", stepKey: "1")
      #expect(loaded == Data("cached".utf8))

      let followerClient = WorkflowClient(endpoints: [cluster.endpoints[2]])
      let onFollower = try await followerClient.load(
        workflowID: "daily-summary-25-05-24",
        stepKey: "1",
        waitForReplication: .seconds(5))
      #expect(onFollower == Data("cached".utf8))
    }
  }

  @Test func workflowContextReplayUsesRaftStore() async throws {
    try await withRaftWorkflowCluster { cluster in
      let store = RaftStepStore(endpoints: cluster.endpoints)

      var callCount = 0
      let ctx1 = WorkflowContext(id: "wf-replay", store: store)
      let first = try await ctx1.step("work") {
        callCount += 1
        return "expensive-result"
      }

      let ctx2 = WorkflowContext(id: "wf-replay", store: store)
      let replay = try await ctx2.step("work") {
        callCount += 1
        return "different"
      }

      #expect(first.value == "expensive-result")
      #expect(replay.value == "expensive-result")
      #expect(callCount == 1)
    }
  }

  @Test func resetClearsReplicatedSteps() async throws {
    try await withRaftWorkflowCluster { cluster in
      let store = RaftStepStore(endpoints: cluster.endpoints)

      let ctx = WorkflowContext(id: "wf-reset", store: store)
      _ = try await ctx.step("keep") { "keep-me" }

      try await store.reset(workflowID: "wf-reset")

      let resetDeadline = ContinuousClock.now + .seconds(5)
      while ContinuousClock.now < resetDeadline {
        if try await store.load(workflowID: "wf-reset", stepKey: "keep") == nil {
          break
        }
        try await Task.sleep(for: .milliseconds(50))
      }

      var callCount = 0
      let freshCtx = WorkflowContext(id: "wf-reset", store: store)
      let fresh = try await freshCtx.step("keep") {
        callCount += 1
        return "new-value"
      }

      #expect(fresh.value == "new-value")
      #expect(callCount == 1)
    }
  }

  @Test func survivesSingleNodeKill() async throws {
    for killedIndex in 0..<3 {
      try await withRaftWorkflowCluster { cluster in
        let store = RaftStepStore(endpoints: cluster.endpoints)
        let workflowID = "chaos-kill-\(killedIndex)"

        try await store.save(workflowID: workflowID, stepKey: "1", data: Data("before".utf8))

        cluster.killNode(at: killedIndex)
        let survivors = cluster.endpoints(excluding: killedIndex)
        try await waitForLeader(endpoints: survivors)

        let activeStore = RaftStepStore(endpoints: survivors)
        try await activeStore.save(workflowID: workflowID, stepKey: "2", data: Data("after".utf8))

        #expect(try await activeStore.load(workflowID: workflowID, stepKey: "1") == Data("before".utf8))
        #expect(try await activeStore.load(workflowID: workflowID, stepKey: "2") == Data("after".utf8))

        let survivor = survivors[0]
        let onSurvivor = try await WorkflowClient(endpoints: [survivor]).load(
          workflowID: workflowID,
          stepKey: "2",
          waitForReplication: .seconds(5))
        #expect(onSurvivor == Data("after".utf8))
      }
    }
  }

  @Test func writeFailsWithoutQuorum() async throws {
    try await withRaftWorkflowCluster { cluster in
      let store = RaftStepStore(endpoints: cluster.endpoints)

      try await store.save(workflowID: "chaos-quorum", stepKey: "1", data: Data("ok".utf8))

      let leaderIndex = try await indexOfLeader(endpoints: cluster.endpoints)
      let followerToKill = (leaderIndex + 1) % 3
      cluster.killNode(at: leaderIndex)
      cluster.killNode(at: followerToKill)
      try await Task.sleep(for: .milliseconds(500))

      let loneIndex = [0, 1, 2].first { $0 != leaderIndex && $0 != followerToKill }!
      let loneStore = RaftStepStore(endpoints: [cluster.endpoints[loneIndex]])

      await #expect(throws: WorkflowClientError.self) {
        try await loneStore.save(workflowID: "chaos-quorum", stepKey: "2", data: Data("blocked".utf8))
      }
    }
  }
}

private final class ManagedRaftWorkflowCluster: @unchecked Sendable {
  let endpoints: [WorkflowEndpoint]
  private let processes: [Process]

  init(endpoints: [WorkflowEndpoint], processes: [Process]) {
    self.endpoints = endpoints
    self.processes = processes
  }

  func killNode(at index: Int) {
    guard processes.indices.contains(index), processes[index].isRunning else { return }
    processes[index].terminate()
  }

  func endpoints(excluding index: Int) -> [WorkflowEndpoint] {
    endpoints.enumerated().filter { $0.offset != index }.map(\.element)
  }
}

private func withRaftWorkflowCluster<R>(
  _ body: (ManagedRaftWorkflowCluster) async throws -> R
) async throws -> R {
  let basePort = 19_000 + Int.random(in: 0..<100) * 10
  let ports = [basePort, basePort + 1, basePort + 2]
  let endpoints = ports.map { WorkflowEndpoint(host: "127.0.0.1", port: $0) }

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

  let cluster = ManagedRaftWorkflowCluster(endpoints: endpoints, processes: processes)
  return try await body(cluster)
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
  endpoints: [WorkflowEndpoint],
  timeout: Duration = .seconds(10)
) async throws {
  let deadline = ContinuousClock.now + timeout
  let store = RaftStepStore(endpoints: endpoints)

  while ContinuousClock.now < deadline {
    do {
      try await store.save(workflowID: "__probe__", stepKey: "0", data: Data("ok".utf8))
      return
    } catch WorkflowClientError.notLeader {
      try await Task.sleep(for: .milliseconds(100))
    }
  }

  throw ClusterTestError.timeout
}

private func indexOfLeader(endpoints: [WorkflowEndpoint]) async throws -> Int {
  for (index, endpoint) in endpoints.enumerated() {
    let store = RaftStepStore(endpoints: [endpoint])
    do {
      try await store.save(workflowID: "__probe__", stepKey: "0", data: Data("x".utf8))
      return index
    } catch WorkflowClientError.notLeader {
      continue
    }
  }
  throw ClusterTestError.noLeader
}

private func waitForPorts(_ ports: [Int], timeout: Duration = .seconds(15)) async throws {
  let allPorts = ports + ports.map { $0 + 1000 }
  let deadline = ContinuousClock.now + timeout
  while ContinuousClock.now < deadline {
    if allPorts.allSatisfy(isPortOpen) {
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
  case noLeader

  var description: String {
    switch self {
    case .missingBinary:
      "Build raft-workflow-node first: swift build --product raft-workflow-node"
    case .timeout:
      "Timed out waiting for raft-workflow-node processes."
    case .noLeader:
      "No Raft leader found among workflow node endpoints."
    }
  }
}
