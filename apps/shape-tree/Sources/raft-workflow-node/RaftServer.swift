import Foundation
import NIOCore
import NIOPosix
import Raft
import RaftWorkflow

actor RaftServer {
  private let onRequestVote: @Sendable (RequestVoteWire) async -> RequestVoteReply
  private let onAppendEntries: @Sendable (AppendEntriesWire) async -> AppendEntryReply
  private let onInstallSnapshot: @Sendable (InstallSnapshotWire) async -> InstallSnapshotReply
  private let onClientCommand: @Sendable (ClientCommandWire) async -> ClientCommandReplyWire
  private let onWorkflowQuery: @Sendable (WorkflowQueryWire) async -> WorkflowQueryReplyWire
  private let eventLoopGroup: MultiThreadedEventLoopGroup
  private var acceptTask: Task<Void, Never>?

  init(
    eventLoopGroup: MultiThreadedEventLoopGroup,
    onRequestVote: @escaping @Sendable (RequestVoteWire) async -> RequestVoteReply,
    onAppendEntries: @escaping @Sendable (AppendEntriesWire) async -> AppendEntryReply,
    onInstallSnapshot: @escaping @Sendable (InstallSnapshotWire) async -> InstallSnapshotReply,
    onClientCommand: @escaping @Sendable (ClientCommandWire) async -> ClientCommandReplyWire,
    onWorkflowQuery: @escaping @Sendable (WorkflowQueryWire) async -> WorkflowQueryReplyWire
  ) {
    self.eventLoopGroup = eventLoopGroup
    self.onRequestVote = onRequestVote
    self.onAppendEntries = onAppendEntries
    self.onInstallSnapshot = onInstallSnapshot
    self.onClientCommand = onClientCommand
    self.onWorkflowQuery = onWorkflowQuery
  }

  func start(host: String, port: Int) async throws {
    let onRequestVote = self.onRequestVote
    let onAppendEntries = self.onAppendEntries
    let onInstallSnapshot = self.onInstallSnapshot
    let onClientCommand = self.onClientCommand
    let onWorkflowQuery = self.onWorkflowQuery

    let listener = try await ServerBootstrap(group: eventLoopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .bind(host: host, port: port) { channel in
        channel.eventLoop.makeCompletedFuture {
          try RaftWorkflowWire.wrap(channel)
        }
      }

    acceptTask = Task {
      do {
        try await listener.executeThenClose { inbound in
          for try await connection in inbound {
            do {
              try await handleConnection(
                connection,
                onRequestVote: onRequestVote,
                onAppendEntries: onAppendEntries,
                onInstallSnapshot: onInstallSnapshot,
                onClientCommand: onClientCommand,
                onWorkflowQuery: onWorkflowQuery
              )
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
    onRequestVote: @Sendable (RequestVoteWire) async -> RequestVoteReply,
    onAppendEntries: @Sendable (AppendEntriesWire) async -> AppendEntryReply,
    onInstallSnapshot: @Sendable (InstallSnapshotWire) async -> InstallSnapshotReply,
    onClientCommand: @Sendable (ClientCommandWire) async -> ClientCommandReplyWire,
    onWorkflowQuery: @Sendable (WorkflowQueryWire) async -> WorkflowQueryReplyWire
  ) async throws {
    try await connection.executeThenClose { inbound, outbound in
      let frame = try await RaftWorkflowWire.readSingleFrame(from: inbound)

      if let wire = try? JSONDecoder().decode(InstallSnapshotWire.self, from: frame) {
        let reply = await onInstallSnapshot(wire)
        let response = try RaftWorkflowWire.encode(InstallSnapshotReplyWire(reply: reply))
        try await outbound.write(response)
      } else if let wire = try? JSONDecoder().decode(RequestVoteWire.self, from: frame) {
        let reply = await onRequestVote(wire)
        let response = try RaftWorkflowWire.encode(RequestVoteReplyWire(reply: reply))
        try await outbound.write(response)
      } else if let wire = try? JSONDecoder().decode(AppendEntriesWire.self, from: frame) {
        let reply = await onAppendEntries(wire)
        let response = try RaftWorkflowWire.encode(AppendEntriesReplyWire(reply: reply))
        try await outbound.write(response)
      } else if let wire = try? JSONDecoder().decode(WorkflowQueryWire.self, from: frame) {
        let reply = await onWorkflowQuery(wire)
        let response = try RaftWorkflowWire.encode(reply)
        try await outbound.write(response)
      } else if let wire = try? JSONDecoder().decode(ClientCommandWire.self, from: frame) {
        let reply = await onClientCommand(wire)
        let response = try RaftWorkflowWire.encode(reply)
        try await outbound.write(response)
      }
    }
  }
}
