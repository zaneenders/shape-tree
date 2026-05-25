import Foundation
import NIOCore
import NIOPosix
import Raft
import RaftWorkflow

struct NetworkPeer: RaftPeer, Sendable {
  let raftNode: Node
  let eventLoopGroup: MultiThreadedEventLoopGroup

  func requestVote(
    _ args: RequestVoteArgs,
    from origin: NetworkPeer
  ) async throws -> RequestVoteReply {
    let wire = RequestVoteWire(origin: origin.raftNode, args: args)
    let requestBuffer = try RaftWorkflowWire.encode(wire)

    let channel = try await ClientBootstrap(group: eventLoopGroup)
      .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .connect(host: raftNode.host, port: raftNode.port) { channel in
        channel.eventLoop.makeCompletedFuture {
          try RaftWorkflowWire.wrap(channel)
        }
      }

    return try await channel.executeThenClose { inbound, outbound in
      try await outbound.write(requestBuffer)
      let frame = try await RaftWorkflowWire.readSingleFrame(from: inbound)
      let replyWire = try JSONDecoder().decode(RequestVoteReplyWire.self, from: frame)
      return replyWire.reply
    }
  }

  func appendEntries(
    _ args: AppendEntryArg,
    from origin: NetworkPeer
  ) async throws -> AppendEntryReply {
    let wire = AppendEntriesWire(origin: origin.raftNode, args: args)
    let requestBuffer = try RaftWorkflowWire.encode(wire)

    let channel = try await ClientBootstrap(group: eventLoopGroup)
      .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .connect(host: raftNode.host, port: raftNode.port) { channel in
        channel.eventLoop.makeCompletedFuture {
          try RaftWorkflowWire.wrap(channel)
        }
      }

    return try await channel.executeThenClose { inbound, outbound in
      try await outbound.write(requestBuffer)
      let frame = try await RaftWorkflowWire.readSingleFrame(from: inbound)
      let replyWire = try JSONDecoder().decode(AppendEntriesReplyWire.self, from: frame)
      return replyWire.reply
    }
  }

  func installSnapshot(
    _ args: InstallSnapshotArgs,
    from origin: NetworkPeer
  ) async throws -> InstallSnapshotReply {
    let wire = InstallSnapshotWire(origin: origin.raftNode, args: args)
    let requestBuffer = try RaftWorkflowWire.encode(wire)

    let channel = try await ClientBootstrap(group: eventLoopGroup)
      .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .connect(host: raftNode.host, port: raftNode.port) { channel in
        channel.eventLoop.makeCompletedFuture {
          try RaftWorkflowWire.wrap(channel)
        }
      }

    return try await channel.executeThenClose { inbound, outbound in
      try await outbound.write(requestBuffer)
      let frame = try await RaftWorkflowWire.readSingleFrame(from: inbound)
      let replyWire = try JSONDecoder().decode(InstallSnapshotReplyWire.self, from: frame)
      return replyWire.reply
    }
  }
}

extension NetworkPeer: Hashable {
  static func == (lhs: NetworkPeer, rhs: NetworkPeer) -> Bool {
    lhs.raftNode == rhs.raftNode
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(raftNode)
  }
}
