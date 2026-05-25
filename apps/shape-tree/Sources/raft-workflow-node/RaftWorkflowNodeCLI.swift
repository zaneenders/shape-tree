import ArgumentParser
import Foundation
import Logging
import NIOPosix
import Raft
import RaftWorkflow

@main
struct RaftWorkflowNodeCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "raft-workflow-node",
    abstract: "Run a Raft-backed workflow replication node.",
    discussion: """
      Example (run in three terminals — order does not matter):

        swift run raft-workflow-node --port 9100 --peer 9101 --peer 9102 --no-wait-for-peers
        swift run raft-workflow-node --port 9101 --peer 9100 --peer 9102 --no-wait-for-peers
        swift run raft-workflow-node --port 9102 --peer 9100 --peer 9101 --no-wait-for-peers

      Docker Compose (from apps/shape-tree):

        docker compose up --build

      Each node waits until all peers are listening before starting elections unless
      `--no-wait-for-peers` is passed.
      """
  )

  @Option(name: .long, help: "Address to bind the TCP listener.")
  var host: String = "127.0.0.1"

  @Option(name: .long, help: "Host name peers use to reach this node (defaults to --host).")
  var advertiseHost: String?

  @Option(name: .long, help: "Port for this node.")
  var port: Int

  @Option(name: .long, help: "Peer address (HOST:PORT or PORT). Repeat for each peer.")
  var peer: [String] = []

  @Option(name: .long, help: "Random election timeout range in milliseconds.")
  var electionTimeoutMs: String = "800-1500"

  @Flag(name: .long, help: "Start election timer immediately without waiting for peers.")
  var noWaitForPeers: Bool = false

  @Option(name: .long, help: "Directory for persistent state (default: data/raft-workflow-node).")
  var storeDir: String = "data/raft-workflow-node"

  @Option(name: .long, help: "Take a snapshot every N committed entries (default: 100, 0 = disabled).")
  var snapshotInterval: UInt = 100

  @Flag(name: .shortAndLong, help: "Enable verbose logging.")
  var verbose: Bool = false

  func validate() throws {
    guard !peer.isEmpty else {
      throw ValidationError("Provide at least one --peer.")
    }
  }

  mutating func run() async throws {
    let peers = try peer.map { try parsePeerAddress($0, defaultHost: host) }
    let (electionTimeoutMin, electionTimeoutMax) = try parseElectionTimeout(electionTimeoutMs)
    let logLevel: Logger.Level = verbose ? .trace : .info

    LoggingSystem.bootstrap { label in
      var handler = StreamLogHandler.standardError(label: label)
      handler.logLevel = logLevel
      return handler
    }
    let logger = Logger(label: "raft-workflow-node")

    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    let raftHost = advertiseHost ?? host
    let myselfNode = Node(host: raftHost, port: port)
    let myself = NetworkPeer(raftNode: myselfNode, eventLoopGroup: group)

    let peerNodes = peers.map { Node(host: $0.host, port: $0.port) }
    let networkPeers = peerNodes.map { NetworkPeer(raftNode: $0, eventLoopGroup: group) }
    let peerRegistry = PeerRegistry(initialPeers: networkPeers, eventLoopGroup: group)

    let settings = Raft.Settings(
      electionTimeoutRange: (min: electionTimeoutMin, max: electionTimeoutMax),
      snapshotInterval: snapshotInterval
    )

    let storeURL = URL(fileURLWithPath: storeDir, isDirectory: true)
    let persister = FilePersister(storeDirectory: storeURL, nodeId: "\(host)-\(port)")
    let shell = await Raft.Shell<NetworkPeer>.make(
      settings: settings,
      myself: myself,
      peers: networkPeers,
      logger: logger,
      persister: persister
    )

    let service = await WorkflowNodeService.make(
      shell: shell,
      logger: logger,
      snapshotInterval: snapshotInterval
    )

    let server = RaftServer(
      eventLoopGroup: group,
      onRequestVote: { wire in
        let fromPeer = await peerRegistry.peer(for: wire.origin)
        await shell.addPeer(fromPeer)
        return await shell.receiveRequestVote(wire.args, from: fromPeer)
      },
      onAppendEntries: { wire in
        let fromPeer = await peerRegistry.peer(for: wire.origin)
        await shell.addPeer(fromPeer)
        return await shell.receiveAppendEntries(wire.args, from: fromPeer)
      },
      onInstallSnapshot: { wire in
        let fromPeer = await peerRegistry.peer(for: wire.origin)
        await shell.addPeer(fromPeer)
        let oldLastIncluded = await shell.snapshotLastIncludedIndex
        let reply = await shell.receiveInstallSnapshot(wire.args, from: fromPeer)
        let newLastIncluded = await shell.snapshotLastIncludedIndex
        if newLastIncluded > oldLastIncluded {
          await service.handleInstallSnapshot(args: wire.args)
        }
        return reply
      },
      onClientCommand: { wire in
        await service.handleClientCommand(wire)
      },
      onWorkflowQuery: { wire in
        await service.handleQuery(wire)
      }
    )

    try await server.start(host: host, port: port)

    logger.info("listening on \(myselfNode)")
    logger.info("peers: \(peerNodes.map(\.description).joined(separator: ", "))")

    if !noWaitForPeers {
      try await PeerReadiness.waitForPeers(peers, eventLoopGroup: group, logger: logger)
    }

    await shell.start()
    await service.startApplyLoop()

    logger.info("waiting for election timeout… (Ctrl+C to stop)")

    while true {
      try await Task.sleep(for: .seconds(3600))
    }
  }
}

actor PeerRegistry {
  private var peersByNode: [Node: NetworkPeer]
  private let eventLoopGroup: MultiThreadedEventLoopGroup

  init(initialPeers: [NetworkPeer], eventLoopGroup: MultiThreadedEventLoopGroup) {
    self.peersByNode = Dictionary(uniqueKeysWithValues: initialPeers.map { ($0.raftNode, $0) })
    self.eventLoopGroup = eventLoopGroup
  }

  func peer(for node: Node) -> NetworkPeer {
    if let p = peersByNode[node] { return p }
    let newPeer = NetworkPeer(raftNode: node, eventLoopGroup: eventLoopGroup)
    peersByNode[node] = newPeer
    return newPeer
  }
}

private enum CLIError: Error, CustomStringConvertible {
  case invalidPeer(String)
  case invalidElectionTimeout(String)

  var description: String {
    switch self {
    case .invalidPeer(let value):
      "invalid --peer value '\(value)', expected HOST:PORT or PORT"
    case .invalidElectionTimeout(let value):
      "invalid --election-timeout-ms value '\(value)', expected MIN-MAX"
    }
  }
}

private func parsePeerAddress(_ value: String, defaultHost: String) throws -> PeerAddress {
  if value.contains(":") {
    let parts = value.split(separator: ":", maxSplits: 1)
    guard parts.count == 2, let port = Int(parts[1]) else {
      throw CLIError.invalidPeer(value)
    }
    return PeerAddress(host: String(parts[0]), port: port)
  }
  guard let port = Int(value) else {
    throw CLIError.invalidPeer(value)
  }
  return PeerAddress(host: defaultHost, port: port)
}

private func parseElectionTimeout(_ value: String) throws -> (UInt, UInt) {
  let parts = value.split(separator: "-")
  guard parts.count == 2,
    let min = UInt(parts[0]),
    let max = UInt(parts[1])
  else {
    throw CLIError.invalidElectionTimeout(value)
  }
  return (min, max)
}
