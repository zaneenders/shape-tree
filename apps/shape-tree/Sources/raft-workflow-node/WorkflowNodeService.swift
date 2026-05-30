import Foundation
import Logging
import Raft
import RaftBlob
import RaftNIO
import RaftShell
import RaftWorkflow

actor WorkflowNodeService {
  private let shell: Raft.Shell<NetworkPeer>
  private let stateMachine: WorkflowStateMachine
  private let blobStore: any BlobStore
  private let logger: Logger
  private let snapshotInterval: UInt

  private var entriesSinceSnapshot: Int = 0

  init(
    shell: Raft.Shell<NetworkPeer>,
    stateMachine: WorkflowStateMachine,
    blobStore: any BlobStore,
    logger: Logger,
    snapshotInterval: UInt
  ) {
    self.shell = shell
    self.stateMachine = stateMachine
    self.blobStore = blobStore
    self.logger = logger
    self.snapshotInterval = snapshotInterval
  }

  static func make(
    shell: Raft.Shell<NetworkPeer>,
    blobStore: any BlobStore,
    logger: Logger,
    snapshotInterval: UInt
  ) async -> WorkflowNodeService {
    let stateMachine = WorkflowStateMachine()
    let service = WorkflowNodeService(
      shell: shell,
      stateMachine: stateMachine,
      blobStore: blobStore,
      logger: logger,
      snapshotInterval: snapshotInterval)

    let (snapIndex, snapData) = await shell.initialSnapshotState()
    if snapIndex > 0, let snapData {
      do {
        try await service.restoreSnapshot(data: snapData, lastIncludedIndex: snapIndex)
      } catch {
        logger.error(
          "failed to restore workflow snapshot",
          metadata: ["error": "\(error)"])
      }
    }

    await shell.setStateMachine(service)
    return service
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
    guard await shell.lastApplied >= result.index else {
      return ClientCommandReplyWire(
        index: result.index,
        term: result.term,
        isLeader: false,
        leaderHint: await shell.currentLeader)
    }
    return ClientCommandReplyWire(
      index: result.index,
      term: result.term,
      isLeader: true)
  }

  func handleQuery(_ wire: WorkflowQueryWire) async -> WorkflowQueryReplyWire {
    guard let ref = await stateMachine.stepRef(workflowID: wire.workflowID, stepKey: wire.stepKey) else {
      return WorkflowQueryReplyWire(found: false, data: nil)
    }
    guard let data = try? await blobStore.get(hash: ref.hash), data.count == ref.byteCount else {
      return WorkflowQueryReplyWire(found: false, data: nil)
    }
    return WorkflowQueryReplyWire(found: true, data: data)
  }

  private func waitApplied(index: Int, timeout: Duration = .seconds(30)) async {
    if await shell.lastApplied >= index { return }
    let deadline = ContinuousClock.now + timeout
    while await shell.lastApplied < index && ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(25))
    }
  }

  private func tryTakeSnapshot() async {
    entriesSinceSnapshot = 0
    let role = await shell.role
    guard role == .leader else { return }

    let index = await shell.commitIndex
    let snapIndex = await shell.snapshotLastIncludedIndex
    guard index > snapIndex else { return }

    let term = await shell.termAt(index)
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

extension WorkflowNodeService: Raft.StateMachineApplier {
  func applyCommitted(_ batch: Raft.ApplyBatch) async throws {
    guard !batch.isEmpty else { return }
    for entry in batch.entries {
      guard let command = entry.command else {
        preconditionFailure("ApplyBatch must contain only command payloads")
      }
      do {
        _ = try await stateMachine.apply(entry: LogEntry(term: entry.term, command: command))
      } catch {
        let preview = String(data: command.prefix(120), encoding: .utf8) ?? "<binary>"
        logger.error(
          "failed to apply workflow entry",
          metadata: [
            "error": "\(error)",
            "commandPrefix": "\(preview)",
          ])
        continue
      }
      entriesSinceSnapshot += 1
    }

    if snapshotInterval > 0, entriesSinceSnapshot >= Int(snapshotInterval) {
      await tryTakeSnapshot()
    }
  }

  func restoreSnapshot(data: Data, lastIncludedIndex: Int) async throws {
    try await stateMachine.restore(from: data)
    entriesSinceSnapshot = 0
    _ = lastIncludedIndex
  }
}
