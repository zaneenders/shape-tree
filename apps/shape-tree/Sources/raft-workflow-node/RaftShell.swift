import Foundation
import Logging
import Raft

extension Raft {
  public actor Shell<Peer: RaftPeer> {
    public private(set) var instance: Instance<Peer>
    private var electionTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    // TODO: this might need to change with membership changes
    private var peerReachable: [Node: Bool] = [:]
    private let clock: any ShellClock
    private let logger: Logger
    private let persister: (any Persister)?

    private var snapshotData: Data?

    private var partialSnapshotData: Data = Data()

    public var currentLeader: Node? { instance.currentLeader }

    public init(
      instance: Instance<Peer>,
      clock: any ShellClock = SystemShellClock(),
      logger: Logger = Logger(label: "raft-shell"),
      persister: (any Persister)? = nil,
      snapshotData: Data? = nil
    ) {
      self.instance = instance
      self.clock = clock
      self.logger = logger
      self.persister = persister
      self.snapshotData = snapshotData
    }

    public static func make(
      settings: Settings = .defaults,
      myself: Peer,
      peers: [Peer],
      clock: any ShellClock = SystemShellClock(),
      logger: Logger = Logger(label: "raft-shell"),
      persister: (any Persister)? = nil
    ) async -> Shell<Peer> {
      var persisted: PersistentState?
      var snap: Data?
      if let p = persister {
        do {
          persisted = try await p.load()
          if let state = persisted {
            logger.info(
              "loaded persisted state",
              metadata: [
                "term": "\(state.currentTerm)",
                "logCount": "\(state.log.count)",
                "lastIncludedIndex": "\(state.lastIncludedIndex)",
              ])

            if state.lastIncludedIndex > 0 {
              if let s = try await p.loadSnapshot() {
                snap = s.data
                logger.info(
                  "loaded snapshot",
                  metadata: [
                    "lastIncludedIndex": "\(s.lastIncludedIndex)",
                    "lastIncludedTerm": "\(s.lastIncludedTerm)",
                    "bytes": "\(s.data.count)",
                  ])
              } else {
                snap = nil
                logger.warning(
                  "persistent state references snapshot but no snapshot file found")
              }
            } else {
              snap = nil
            }
          } else {
            persisted = nil
            snap = nil
          }
        } catch {
          logger.warning(
            "failed to load persisted state, starting fresh",
            metadata: ["error": "\(error)"])
          persisted = nil
          snap = nil
        }
      } else {
        persisted = nil
        snap = nil
      }

      return Shell(
        instance: Instance(
          settings: settings,
          myself: myself,
          peers: peers,
          persistedState: persisted),
        clock: clock,
        logger: logger,
        persister: persister,
        snapshotData: snap)
    }

    public func start() async {
      await scheduleElectionTimeout(delay: instance.settings.randomElectionTimeout)
    }

    public func start(command: Data) -> (index: Int, term: Int, isLeader: Bool) {
      let result = instance.start(command: command)
      if result.isLeader {
        logger.info(
          "received command",
          metadata: [
            "index": "\(result.index)",
            "term": "\(result.term)",
          ])
        Task { [weak self] in await self?.persist() }

        Task { [weak self] in await self?.replicateToAll() }
      }
      return result
    }

    public func proposeMembershipChange(to newConfiguration: Set<Node>) -> (index: Int, term: Int, isLeader: Bool) {
      let result = instance.proposeMembershipChange(to: newConfiguration)
      if result.isLeader {
        logger.info(
          "proposed membership change",
          metadata: [
            "index": "\(result.index)",
            "term": "\(result.term)",
            "newConfig": "\(newConfiguration.map(\.description))",
          ])
        Task { [weak self] in await self?.persist() }
        Task { [weak self] in await self?.replicateToAll() }
      }
      return result
    }

    public func addPeer(_ peer: Peer) {
      instance.addPeer(peer)
    }

    public func removePeer(_ node: Node) {
      instance.removePeer(node)
    }

    public func takeSnapshot(index: Int, term: Int, data: Data) -> Bool {
      guard instance.takeSnapshot(index: index, term: term) else {
        logger.warning(
          "rejected snapshot",
          metadata: [
            "index": "\(index)",
            "term": "\(term)",
          ])
        return false
      }

      snapshotData = data
      logger.info(
        "snapshot taken",
        metadata: [
          "index": "\(instance.lastIncludedIndex)",
          "term": "\(instance.lastIncludedTerm)",
          "logRemaining": "\(instance.log.count)",
        ])

      Task { [weak self] in
        guard let self else { return }
        await self.persist()
        await self.persistSnapshot()
      }
      return true
    }

    public var currentSnapshotData: Data? {
      snapshotData
    }

    public var snapshotLastIncludedIndex: Int {
      instance.lastIncludedIndex
    }

    public func initialSnapshotState() async -> (index: Int, data: Data?) {
      (instance.lastIncludedIndex, snapshotData)
    }

    public func stop() {
      electionTask?.cancel()
      heartbeatTask?.cancel()
    }

    public func receiveElectionTimeout() async {
      let directives = instance.onElectionTimeout()
      await persist()
      await executeElectionTimeout(directives)
    }

    public func receiveRequestVote(
      _ args: RequestVoteArgs,
      from peer: Peer
    ) async -> RequestVoteReply {
      let directives = instance.onRequestVote(args, from: peer)
      await persist()
      var reply = RequestVoteReply(term: instance.currentTerm, voteGranted: false)
      for directive in directives {
        switch directive {
        case .reply(let r):
          reply = r
        case .scheduleElectionTimeout(let delay):
          await scheduleElectionTimeout(delay: delay)
        case .stepDown:
          break
        }
      }
      return reply
    }

    public func receiveRequestVoteReply(
      _ reply: RequestVoteReply,
      from peer: Peer
    ) async {
      let directives = instance.onRequestVoteReply(reply, from: peer)
      await persist()
      await executeRequestVoteReply(directives)
    }

    public func receiveAppendEntries(
      _ args: AppendEntryArg,
      from peer: Peer
    ) async -> AppendEntryReply {
      let directives = instance.onAppendEntries(args, from: peer)
      await persist()
      var reply = AppendEntryReply(term: instance.currentTerm, success: false)
      for directive in directives {
        switch directive {
        case .reply(let r):
          reply = r
          if args.entries.isEmpty && r.success {
            logger.trace(
              "received heartbeat",
              metadata: [
                "leader": "\(peer.raftNode)",
                "term": "\(instance.currentTerm)",
              ])
          } else if !args.entries.isEmpty && r.success {
            logger.info(
              "appended entries",
              metadata: [
                "leader": "\(peer.raftNode)",
                "term": "\(instance.currentTerm)",
                "count": "\(args.entries.count)",
                "prevLogIndex": "\(args.prevLogIndex)",
              ])
          }
        case .scheduleElectionTimeout(let delay):
          await scheduleElectionTimeout(delay: delay)
        case .stepDown:
          break
        }
      }
      return reply
    }

    public func receiveAppendEntriesReply(
      _ reply: AppendEntryReply,
      from peer: Peer,
      for args: AppendEntryArg
    ) async {
      let directives = instance.onAppendEntriesReply(reply, from: peer, for: args)
      await persist()
      for directive in directives {
        switch directive {
        case .stepDown(let term):
          logger.info("stepped down to term", metadata: ["term": "\(term)"])
          heartbeatTask?.cancel()
          heartbeatTask = nil
        case .scheduleElectionTimeout(let delay):
          await scheduleElectionTimeout(delay: delay)
        case .sendAppendEntries(let node, let args):
          await executeSendAppendEntries(node, args)
        case .sendInstallSnapshot(let node, var args):
          // Fill in the actual snapshot data (Instance doesn't carry it).
          args = InstallSnapshotArgs(
            term: args.term,
            leaderId: args.leaderId,
            lastIncludedIndex: args.lastIncludedIndex,
            lastIncludedTerm: args.lastIncludedTerm,
            offset: args.offset,
            data: snapshotData ?? Data(),
            done: args.done)
          await executeSendInstallSnapshot(node, args)
        case .none:
          logger.trace(
            "heartbeat acknowledged",
            metadata: [
              "peer": "\(peer.raftNode)"
            ])
          break
        }
      }
    }

    public func receiveInstallSnapshot(
      _ args: InstallSnapshotArgs,
      from peer: Peer
    ) async -> InstallSnapshotReply {
      let directives = instance.onInstallSnapshot(args, from: peer)
      await persist()
      for directive in directives {
        switch directive {
        case .saveSnapshot:
          // Final chunk — assemble the full snapshot.
          partialSnapshotData.append(args.data)
          snapshotData = partialSnapshotData
          partialSnapshotData = Data()
          await persistSnapshot()
        case .accumulateSnapshot:
          partialSnapshotData.append(args.data)
        default:
          break
        }
      }
      var reply = InstallSnapshotReply(term: instance.currentTerm)
      for directive in directives {
        if case .reply(let r) = directive {
          reply = r
        }
      }
      return reply
    }

    public func receiveInstallSnapshotReply(
      _ reply: InstallSnapshotReply,
      from peer: Peer,
      for args: InstallSnapshotArgs
    ) async {
      let directives = instance.onInstallSnapshotReply(reply, from: peer, for: args)
      await persist()
      for directive in directives {
        switch directive {
        case .stepDown(let term):
          logger.info("stepped down to term", metadata: ["term": "\(term)"])
          heartbeatTask?.cancel()
          heartbeatTask = nil
        case .scheduleElectionTimeout(let delay):
          await scheduleElectionTimeout(delay: delay)
        case .sendAppendEntries(let node, let args):
          await executeSendAppendEntries(node, args)
        case .sendInstallSnapshot(let node, let args):
          await executeSendInstallSnapshot(node, args)
        case .none:
          break
        }
      }
    }

    private func persist() async {
      guard let p = persister else { return }
      let state = instance.persistentState
      do {
        try await p.save(state: state)
      } catch {
        logger.error(
          "failed to persist state",
          metadata: [
            "term": "\(state.currentTerm)",
            "logCount": "\(state.log.count)",
            "error": "\(error)",
          ])
      }
    }

    private func persistSnapshot() async {
      guard let p = persister else { return }
      guard let data = snapshotData else { return }
      do {
        try await p.saveSnapshot(
          data: data,
          lastIncludedIndex: instance.lastIncludedIndex,
          lastIncludedTerm: instance.lastIncludedTerm)
      } catch {
        logger.error(
          "failed to persist snapshot",
          metadata: [
            "lastIncludedIndex": "\(instance.lastIncludedIndex)",
            "error": "\(error)",
          ])
      }
    }

    private func executeRequestVoteReply(_ directives: [RequestVoteReplyDirective]) async {
      for directive in directives {
        switch directive {
        case .becomeLeader(let term):
          logger.info("became leader", metadata: ["term": "\(term)"])
        case .scheduleElectionTimeout(let delay):
          await scheduleElectionTimeout(delay: delay)
        case .cancelElectionTimeout:
          electionTask?.cancel()
          electionTask = nil
        case .stepDown(let term):
          logger.info("stepped down to term", metadata: ["term": "\(term)"])
          heartbeatTask?.cancel()
          heartbeatTask = nil
        case .sendAppendEntries(peer: let node, let args):
          await executeSendAppendEntries(node, args)
        case .scheduleHeartbeat(let delay):
          await scheduleHeartbeat(delay: delay)
        }
      }
    }

    private func executeSendAppendEntries(_ node: Node, _ args: AppendEntryArg) async {
      guard let peer = peer(for: node) else { return }
      do {
        let reply = try await peer.appendEntries(args, from: instance.member.peer)
        notePeerSuccess(node)
        await receiveAppendEntriesReply(reply, from: peer, for: args)
      } catch {
        notePeerError(node, context: "appendEntries")
      }
    }

    private func executeSendInstallSnapshot(_ node: Node, _ args: InstallSnapshotArgs) async {
      guard let peer = peer(for: node) else { return }
      do {
        let reply = try await peer.installSnapshot(args, from: instance.member.peer)
        notePeerSuccess(node)
        await receiveInstallSnapshotReply(reply, from: peer, for: args)
      } catch {
        notePeerError(node, context: "installSnapshot")
      }
    }

    private func executeElectionTimeout(_ directives: [ElectionTimeoutDirective]) async {
      for directive in directives {
        switch directive {
        case .startElection(let term):
          logger.info("starting election", metadata: ["term": "\(term)"])
        case .sendRequestVote(let node, let args):
          guard let peer = peer(for: node) else { continue }
          let origin = instance.member.peer
          Task { [weak self] in
            guard let self else { return }
            do {
              let reply = try await peer.requestVote(args, from: origin)
              await self.notePeerSuccess(node)
              await self.receiveRequestVoteReply(reply, from: peer)
            } catch {
              await self.notePeerError(node, context: "requestVote")
            }
          }
        case .scheduleElectionTimeout(let delay):
          await scheduleElectionTimeout(delay: delay)
        case .becomeLeader(let term):
          logger.info("became leader", metadata: ["term": "\(term)"])
        case .cancelElectionTimeout:
          electionTask?.cancel()
          electionTask = nil
        case .scheduleHeartbeat(let delay):
          await scheduleHeartbeat(delay: delay)
        case .sendAppendEntries(let node, let args):
          await executeSendAppendEntries(node, args)
        }
      }
    }

    private func scheduleHeartbeat(delay: Duration) async {
      heartbeatTask?.cancel()
      heartbeatTask = Task { [weak self] in
        while !Task.isCancelled {
          await self?.clock.sleep(for: delay)
          if Task.isCancelled { return }
          guard let self else { return }
          await self.sendHeartbeats()
        }
      }
    }

    private func sendHeartbeats() async {
      guard instance.role == .leader else {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        return
      }

      logger.trace(
        "sending heartbeats",
        metadata: [
          "term": "\(instance.currentTerm)",
          "peers": "\(instance.peers.map(\.raftNode.description))",
        ])

      await replicateToAll()
    }

    private func replicateToAll() async {
      guard instance.role == .leader else { return }

      for peer in instance.peers {
        let node = peer.raftNode

        if instance.needsSnapshot(for: node) {
          let args = InstallSnapshotArgs(
            term: instance.currentTerm,
            leaderId: instance.raftNode,
            lastIncludedIndex: instance.lastIncludedIndex,
            lastIncludedTerm: instance.lastIncludedTerm,
            data: snapshotData ?? Data())
          logger.info(
            "sending snapshot to peer",
            metadata: [
              "peer": "\(node)",
              "lastIncludedIndex": "\(args.lastIncludedIndex)",
              "bytes": "\(args.data.count)",
            ])
          Task { [weak self] in
            guard let self else { return }
            do {
              let reply = try await peer.installSnapshot(
                args, from: await self.instance.member.peer)
              await self.notePeerSuccess(node)
              await self.receiveInstallSnapshotReply(reply, from: peer, for: args)
            } catch {
              await self.notePeerError(node, context: "installSnapshot")
            }
          }
        } else if let args = instance.appendEntriesArgs(for: node) {
          if !args.entries.isEmpty {
            logger.info(
              "replicating entries",
              metadata: [
                "peer": "\(node)",
                "term": "\(instance.currentTerm)",
                "count": "\(args.entries.count)",
                "prevLogIndex": "\(args.prevLogIndex)",
              ])
          }
          Task { [weak self] in
            guard let self else { return }
            do {
              let reply = try await peer.appendEntries(
                args, from: await self.instance.member.peer)
              await self.notePeerSuccess(node)
              await self.receiveAppendEntriesReply(reply, from: peer, for: args)
            } catch {
              await self.notePeerError(node, context: "appendEntries")
            }
          }
        }
      }
    }

    private func peer(for node: Node) -> Peer? {
      instance.peers.first { $0.raftNode == node }
    }

    private func notePeerError(_ node: Node, context: String) {
      let wasReachable = peerReachable[node] ?? true
      if wasReachable {
        peerReachable[node] = false
        logger.warning(
          "lost contact with peer",
          metadata: [
            "peer": "\(node)",
            "context": "\(context)",
          ])
      }
    }

    private func notePeerSuccess(_ node: Node) {
      let wasReachable = peerReachable[node] ?? true
      if !wasReachable {
        peerReachable[node] = true
        logger.info(
          "reestablished contact with peer",
          metadata: [
            "peer": "\(node)"
          ])
      } else {
        peerReachable[node] = true
      }
    }

    private func scheduleElectionTimeout(delay: Duration) async {
      electionTask?.cancel()
      electionTask = Task { [weak self] in
        await self?.clock.sleep(for: delay)
        guard !Task.isCancelled, let self else { return }
        await self.receiveElectionTimeout()
      }
    }
  }

  public protocol ShellClock: Sendable {
    func sleep(for duration: Duration) async
  }

  public struct SystemShellClock: ShellClock, Sendable {
    public init() {}

    public func sleep(for duration: Duration) async {
      try? await Task.sleep(for: duration)
    }
  }
}
