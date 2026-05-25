import Foundation
import NIOCore
import NIOPosix

public struct RaftWorkflowEndpoint: Sendable, Equatable, Codable {
  public let host: String
  public let port: Int

  public init(host: String = "127.0.0.1", port: Int) {
    self.host = host
    self.port = port
  }
}

public enum RaftWorkflowError: Error, Sendable, CustomStringConvertible {
  case notLeader
  case noEndpoints
  case requestFailed(String)

  public var description: String {
    switch self {
    case .notLeader:
      "No Raft leader accepted the workflow command."
    case .noEndpoints:
      "Provide at least one workflow node endpoint."
    case .requestFailed(let message):
      message
    }
  }
}

public actor RaftWorkflowClient {
  private let endpoints: [RaftWorkflowEndpoint]
  private var preferredEndpoint: RaftWorkflowEndpoint?

  public init(endpoints: [RaftWorkflowEndpoint]) {
    self.endpoints = endpoints
    if endpoints.count == 1 {
      preferredEndpoint = endpoints[0]
    }
  }

  public func propose(_ command: WorkflowCommand) async throws {
    let encoded = try WorkflowCodec.encode(command)
    let reply = try await sendCommand(encoded)
    guard reply.isLeader else {
      throw RaftWorkflowError.notLeader
    }
  }

  public func load(workflowID: String, stepKey: String) async throws -> Data? {
    let ordered = orderedEndpoints()
    guard !ordered.isEmpty else { throw RaftWorkflowError.noEndpoints }

    var lastError: Error?
    for endpoint in ordered {
      do {
        let wire = WorkflowQueryWire(workflowID: workflowID, stepKey: stepKey)
        let frame = try await send(wire, to: endpoint)
        let reply = try JSONDecoder().decode(WorkflowQueryReplyWire.self, from: frame)
        preferredEndpoint = endpoint
        return reply.found ? reply.data : nil
      } catch {
        lastError = error
      }
    }

    throw lastError ?? RaftWorkflowError.requestFailed("Failed to query any workflow node.")
  }

  private func sendCommand(_ command: Data) async throws -> ClientCommandReplyWire {
    let ordered = orderedEndpoints()
    guard !ordered.isEmpty else { throw RaftWorkflowError.noEndpoints }

    var lastNotLeader: ClientCommandReplyWire?
    for endpoint in ordered {
      do {
        let wire = ClientCommandWire(command: command)
        let frame = try await send(wire, to: endpoint)
        let reply = try JSONDecoder().decode(ClientCommandReplyWire.self, from: frame)
        if reply.isLeader {
          preferredEndpoint = endpoint
          return reply
        }
        lastNotLeader = reply
      } catch {
        continue
      }
    }

    if lastNotLeader != nil {
      throw RaftWorkflowError.notLeader
    }
    throw RaftWorkflowError.requestFailed("Failed to reach any workflow node.")
  }

  private func orderedEndpoints() -> [RaftWorkflowEndpoint] {
    guard let preferredEndpoint else { return endpoints }
    return [preferredEndpoint] + endpoints.filter { $0 != preferredEndpoint }
  }

  private func send<T: Encodable>(_ message: T, to endpoint: RaftWorkflowEndpoint) async throws -> Data {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    let requestBuffer = try RaftWorkflowWire.encode(message)

    let channel = try await ClientBootstrap(group: group)
      .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .connect(host: endpoint.host, port: endpoint.port) { channel in
        channel.eventLoop.makeCompletedFuture {
          try RaftWorkflowWire.wrap(channel)
        }
      }

    let frame = try await channel.executeThenClose { inbound, outbound in
      try await outbound.write(requestBuffer)
      return try await RaftWorkflowWire.readSingleFrame(from: inbound)
    }

    try await group.shutdownGracefully()
    return frame
  }
}
