import Foundation
import Logging
import NIOCore
import NIOPosix
import Raft
import RaftWorkflow

enum PeerReadiness {
  static func waitForPeers(
    _ peers: [PeerAddress],
    eventLoopGroup: MultiThreadedEventLoopGroup,
    logger: Logger
  ) async throws {
    guard !peers.isEmpty else { return }

    logger.info("waiting for peers to come online…")
    var pollsSinceStatus = 0
    while true {
      var offline: [PeerAddress] = []
      for peer in peers {
        let reachable = await isPortOpen(
          host: peer.host,
          port: peer.port,
          eventLoopGroup: eventLoopGroup
        )
        if !reachable {
          offline.append(peer)
        }
      }

      if offline.isEmpty {
        logger.info("all peers online, starting election timer")
        return
      }

      pollsSinceStatus += 1
      if pollsSinceStatus == 1 || pollsSinceStatus % 8 == 0 {
        let waitingFor = offline.map { "\($0.host):\($0.port)" }.joined(separator: ", ")
        logger.info("still waiting for peers: \(waitingFor)")
      }

      try await Task.sleep(for: .milliseconds(250))
    }
  }

  private static func isPortOpen(
    host: String,
    port: Int,
    eventLoopGroup: MultiThreadedEventLoopGroup
  ) async -> Bool {
    await withCheckedContinuation { continuation in
      let bootstrap = ClientBootstrap(group: eventLoopGroup)
        .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .channelInitializer { channel in
          channel.eventLoop.makeSucceededFuture(())
        }

      bootstrap.connect(host: host, port: port).whenComplete { result in
        switch result {
        case .success(let channel):
          channel.close(promise: nil)
          continuation.resume(returning: true)
        case .failure:
          continuation.resume(returning: false)
        }
      }
    }
  }
}

struct PeerAddress: Equatable {
  var host: String
  var port: Int
}
