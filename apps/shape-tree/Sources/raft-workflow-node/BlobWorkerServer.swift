import Foundation
import Logging
import NIOCore
import NIOPosix
import RaftBlob
import RaftNIO

actor BlobWorkerServer {
  private let eventLoopGroup: MultiThreadedEventLoopGroup
  private let blobStore: any BlobStore
  private var acceptTask: Task<Void, Never>?

  init(eventLoopGroup: MultiThreadedEventLoopGroup, blobStore: any BlobStore) {
    self.eventLoopGroup = eventLoopGroup
    self.blobStore = blobStore
  }

  func start(host: String, port: Int) async throws {
    let blobStore = self.blobStore
    let listener = try await ServerBootstrap(group: eventLoopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .bind(host: host, port: port) { channel in
        channel.eventLoop.makeCompletedFuture {
          try RaftAsyncChannel.wrap(channel)
        }
      }

    acceptTask = Task {
      do {
        try await listener.executeThenClose { inbound in
          for try await connection in inbound {
            do {
              try await handleConnection(connection, blobStore: blobStore)
            } catch {
              continue
            }
          }
        }
      } catch {
        return
      }
    }
  }

  private func handleConnection(
    _ connection: NIOAsyncChannel<ByteBuffer, ByteBuffer>,
    blobStore: any BlobStore
  ) async throws {
    try await connection.executeThenClose { inbound, outbound in
      let frame = try await WireCodec.readSingleFrame(from: inbound)
      let reply = try await BlobServer.handleFrame(frame, blobStore: blobStore)
      try await outbound.write(reply)
    }
  }
}
