import Foundation
import NIOCore
import Raft

public struct ClientCommandWire: Codable, Sendable {
  public let command: Data

  public init(command: Data) {
    self.command = command
  }
}

public struct ClientCommandReplyWire: Codable, Sendable {
  public let index: Int
  public let term: Int
  public let isLeader: Bool
  public let leaderHint: Node?

  public init(index: Int, term: Int, isLeader: Bool, leaderHint: Node? = nil) {
    self.index = index
    self.term = term
    self.isLeader = isLeader
    self.leaderHint = leaderHint
  }
}

public struct WorkflowQueryWire: Codable, Sendable {
  public let workflowID: String
  public let stepKey: String

  public init(workflowID: String, stepKey: String) {
    self.workflowID = workflowID
    self.stepKey = stepKey
  }
}

public struct WorkflowQueryReplyWire: Codable, Sendable {
  public let found: Bool
  public let data: Data?

  public init(found: Bool, data: Data?) {
    self.found = found
    self.data = data
  }
}

public struct RequestVoteWire: Codable, Sendable {
  public let origin: Node
  public let args: RequestVoteArgs

  public init(origin: Node, args: RequestVoteArgs) {
    self.origin = origin
    self.args = args
  }
}

public struct RequestVoteReplyWire: Codable, Sendable {
  public let reply: RequestVoteReply

  public init(reply: RequestVoteReply) {
    self.reply = reply
  }
}

public struct AppendEntriesWire: Codable, Sendable {
  public let origin: Node
  public let args: AppendEntryArg

  public init(origin: Node, args: AppendEntryArg) {
    self.origin = origin
    self.args = args
  }
}

public struct AppendEntriesReplyWire: Codable, Sendable {
  public let reply: AppendEntryReply

  public init(reply: AppendEntryReply) {
    self.reply = reply
  }
}

public struct InstallSnapshotWire: Codable, Sendable {
  public let origin: Node
  public let args: InstallSnapshotArgs

  public init(origin: Node, args: InstallSnapshotArgs) {
    self.origin = origin
    self.args = args
  }
}

public struct InstallSnapshotReplyWire: Codable, Sendable {
  public let reply: InstallSnapshotReply

  public init(reply: InstallSnapshotReply) {
    self.reply = reply
  }
}

public enum RaftWorkflowWireError: Error, Sendable {
  case incompleteFrame
}

public enum RaftWorkflowWire {
  public static func encode<T: Encodable>(_ value: T) throws -> ByteBuffer {
    let data = try JSONEncoder().encode(value)
    var buffer = ByteBufferAllocator().buffer(capacity: 4 + data.count)
    buffer.writeInteger(UInt32(data.count), endianness: .big)
    buffer.writeBytes(data)
    return buffer
  }

  public static func readFrame(from buffer: inout ByteBuffer) throws -> Data? {
    guard buffer.readableBytes >= 4 else { return nil }

    var peek = buffer
    guard let length = peek.readInteger(endianness: .big, as: UInt32.self) else { return nil }
    let totalLength = 4 + Int(length)
    guard buffer.readableBytes >= totalLength else { return nil }

    buffer.moveReaderIndex(forwardBy: 4)
    guard let bytes = buffer.readBytes(length: Int(length)) else { return nil }
    return Data(bytes)
  }

  public static func readSingleFrame(
    from inbound: NIOAsyncChannelInboundStream<ByteBuffer>
  ) async throws -> Data {
    var buffer = ByteBuffer()
    for try await var chunk in inbound {
      buffer.writeBuffer(&chunk)
      if let frame = try readFrame(from: &buffer) {
        return frame
      }
    }
    throw RaftWorkflowWireError.incompleteFrame
  }

  public static let asyncChannelConfiguration = NIOAsyncChannel<ByteBuffer, ByteBuffer>.Configuration(
    inboundType: ByteBuffer.self,
    outboundType: ByteBuffer.self
  )

  public static func wrap(_ channel: Channel) throws -> NIOAsyncChannel<ByteBuffer, ByteBuffer> {
    try NIOAsyncChannel(
      wrappingChannelSynchronously: channel,
      configuration: asyncChannelConfiguration
    )
  }
}
