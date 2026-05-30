import ArgumentParser
import Foundation
import Logging
import NIOPosix
import Raft
import RaftBlob
import RaftExtras
import RaftNIO
import RaftShell
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
      `--no-wait-for-peers` is passed. Blob storage listens on the Raft port + 1000.
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

  @Option(name: .long, help: "Blob listener port (default: Raft port + 1000).")
  var workerPort: Int?

  @Flag(name: .shortAndLong, help: "Enable verbose logging.")
  var verbose: Bool = false

  func validate() throws {
    guard !peer.isEmpty else {
      throw ValidationError("Provide at least one --peer.")
    }
  }

  mutating func run() async throws {
    let peerDefaultHost = EndpointAddressParser.peerDefaultHost(
      bindHost: host,
      advertiseHost: advertiseHost)
    let peers = try peer.map { try EndpointAddressParser.parse($0, defaultHost: peerDefaultHost) }
    let (electionTimeoutMin, electionTimeoutMax) = try parseElectionTimeout(electionTimeoutMs)
    let logLevel: Logger.Level = verbose ? .trace : .info
    let resolvedWorkerPort = workerPort ?? (port + 1000)

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
      electionTimeoutMin: electionTimeoutMin,
      electionTimeoutMax: electionTimeoutMax,
      snapshotInterval: snapshotInterval
    )

    let storeURL = URL(fileURLWithPath: storeDir, isDirectory: true)
    let blobStore = try FileBlobStore(directory: storeURL.appendingPathComponent("blobs"))
    let persister = try FilePersister(storeDirectory: storeURL, nodeId: "\(host)-\(port)")
    let shell = await Raft.Shell<NetworkPeer>.make(
      settings: settings,
      myself: myself,
      peers: networkPeers,
      logger: logger,
      persister: persister
    )

    let service = await WorkflowNodeService.make(
      shell: shell,
      blobStore: blobStore,
      logger: logger,
      snapshotInterval: snapshotInterval
    )

    let blobServer = BlobWorkerServer(eventLoopGroup: group, blobStore: blobStore)
    try await blobServer.start(host: host, port: resolvedWorkerPort)

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
        return await shell.receiveInstallSnapshot(wire.args, from: fromPeer)
      },
      onClientCommand: { wire in
        await service.handleClientCommand(wire)
      },
      customFrameHandler: { frame in
        if let wire = try? JSONDecoder().decode(WorkflowQueryWire.self, from: frame) {
          let reply = await service.handleQuery(wire)
          return try WireCodec.encode(reply)
        }
        return nil
      },
      logger: logger
    )

    try await server.start(host: host, port: port)

    logger.info("listening on \(myselfNode)")
    logger.info("blob listener on \(raftHost):\(resolvedWorkerPort)")
    logger.info("peers: \(peerNodes.map(\.description).joined(separator: ", "))")

    if !noWaitForPeers {
      try await PeerReadiness.waitForPeers(
        peers.map { PeerAddress(host: $0.host, port: $0.port) },
        eventLoopGroup: group,
        logger: logger)
    }

    await shell.start()

    logger.info("waiting for election timeout… (Ctrl+C to stop)")

    while true {
      try await Task.sleep(for: .seconds(3600))
    }
  }
}

private enum CLIError: Error, CustomStringConvertible {
  case invalidElectionTimeout(String)

  var description: String {
    switch self {
    case .invalidElectionTimeout(let value):
      "invalid --election-timeout-ms value '\(value)', expected MIN-MAX"
    }
  }
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
