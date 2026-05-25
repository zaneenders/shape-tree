import Foundation
import Logging
import NIOCore
import NIOPosix
import Raft
import RaftWorkflow

actor WorkflowNodeService {
  private let shell: Raft.Shell<NetworkPeer>
  private let stateMachine: WorkflowStateMachine
  private let logger: Logger
  private let snapshotInterval: UInt

  private var localLastApplied: Int = 0
  private var entriesSinceSnapshot: Int = 0
  private var appliedWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

  init(
    shell: Raft.Shell<NetworkPeer>,
    stateMachine: WorkflowStateMachine,
    logger: Logger,
    snapshotInterval: UInt,
    initialLastApplied: Int = 0
  ) {
    self.shell = shell
    self.stateMachine = stateMachine
    self.logger = logger
    self.snapshotInterval = snapshotInterval
    self.localLastApplied = initialLastApplied
  }

  static func make(
    shell: Raft.Shell<NetworkPeer>,
    logger: Logger,
    snapshotInterval: UInt
  ) async -> WorkflowNodeService {
    let stateMachine = WorkflowStateMachine()
    let (snapIndex, snapData) = await shell.initialSnapshotState()
    if snapIndex > 0, let snapData {
      do {
        try await stateMachine.restore(from: snapData)
      } catch {
        logger.error(
          "failed to restore workflow snapshot",
          metadata: ["error": "\(error)"])
      }
    }

    return WorkflowNodeService(
      shell: shell,
      stateMachine: stateMachine,
      logger: logger,
      snapshotInterval: snapshotInterval,
      initialLastApplied: snapIndex)
  }

  func startApplyLoop() {
    Task { [weak self] in
      await self?.runApplyLoop()
    }
  }

  func handleClientCommand(_ wire: ClientCommandWire) async -> ClientCommandReplyWire {
    let result = await shell.start(command: wire.command)
    if !result.isLeader {
      return ClientCommandReplyWire(
        index: result.index,
        term: result.term,
        isLeader: false,
        leaderHint: await shell.currentLeader)
    }

    await waitApplied(index: result.index)
    return ClientCommandReplyWire(
      index: result.index,
      term: result.term,
      isLeader: true)
  }

  func handleQuery(_ wire: WorkflowQueryWire) async -> WorkflowQueryReplyWire {
    let data = await stateMachine.load(workflowID: wire.workflowID, stepKey: wire.stepKey)
    return WorkflowQueryReplyWire(found: data != nil, data: data)
  }

  func handleInstallSnapshot(args: InstallSnapshotArgs) async {
    guard !args.data.isEmpty else { return }
    do {
      try await stateMachine.restore(from: args.data)
      let commitIndex = await shell.instance.commitIndex
      localLastApplied = max(localLastApplied, commitIndex)
    } catch {
      logger.error(
        "failed to restore workflow snapshot from install",
        metadata: ["error": "\(error)"])
    }
  }

  private func waitApplied(index: Int) async {
    if localLastApplied >= index { return }
    await withCheckedContinuation { continuation in
      appliedWaiters[index, default: []].append(continuation)
    }
  }

  private func runApplyLoop() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(10))
      await applyOnce()
    }
  }

  private func applyOnce() async {
    let commitIndex = await shell.instance.commitIndex
    let log = await shell.instance.log
    let snapOffset = await shell.snapshotLastIncludedIndex

    while localLastApplied < commitIndex {
      localLastApplied += 1
      let arrayPos = localLastApplied - snapOffset - 1
      guard arrayPos >= 0, arrayPos < log.count else { continue }

      do {
        _ = try await stateMachine.apply(entry: log[arrayPos])
      } catch {
        logger.error(
          "failed to apply workflow entry",
          metadata: [
            "index": "\(localLastApplied)",
            "error": "\(error)",
          ])
        continue
      }

      entriesSinceSnapshot += 1
      resumeWaiters(upTo: localLastApplied)
    }

    if snapshotInterval > 0, entriesSinceSnapshot >= Int(snapshotInterval) {
      await tryTakeSnapshot()
    }
  }

  private func resumeWaiters(upTo index: Int) {
    for waitingIndex in appliedWaiters.keys where waitingIndex <= index {
      for continuation in appliedWaiters.removeValue(forKey: waitingIndex) ?? [] {
        continuation.resume()
      }
    }
  }

  private func tryTakeSnapshot() async {
    entriesSinceSnapshot = 0
    let role = await shell.instance.role
    guard role == .leader else { return }

    let index = await shell.instance.commitIndex
    let snapIndex = await shell.snapshotLastIncludedIndex
    guard index > snapIndex else { return }

    let term = await shell.instance.log.last?.term ?? 0
    guard term > 0 else { return }

    let data: Data
    do {
      data = try await stateMachine.snapshot()
    } catch {
      logger.error("failed to encode workflow snapshot", metadata: ["error": "\(error)"])
      return
    }

    let ok = await shell.takeSnapshot(index: index, term: term, data: data)
    if ok {
      logger.info(
        "workflow snapshot created",
        metadata: [
          "index": "\(index)",
          "term": "\(term)",
          "bytes": "\(data.count)",
        ])
    }
  }
}
