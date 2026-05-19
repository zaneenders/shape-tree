import Foundation

public struct NodeID: Hashable, Sendable, Codable, CustomStringConvertible {
  public var rawValue: UUID

  public init() {
    rawValue = UUID()
  }

  public init(rawValue: UUID) {
    self.rawValue = rawValue
  }

  public var description: String { rawValue.uuidString }
}

/// Where a node sits in the tree.
///
/// - ``root``: this node is the tree root (stored on the root node only), or when creating a node,
///   attach it under the tree root.
/// - ``node(_:)``: this node's parent is the given id (or when creating, attach under that node).
public enum ParentId: Sendable, Codable, Equatable {
  case root
  case node(NodeID)
}

extension ParentId {
  public var parentNodeID: NodeID? {
    guard case .node(let id) = self else { return nil }
    return id
  }
}

/// A tree node: structural fields plus a ``payload`` serialized in `node.json`.
public struct TreeNode<Payload: Codable & Sendable>: Sendable, Codable, Identifiable {
  public var id: NodeID
  public var parentId: ParentId
  public var createdAt: Date
  public var payload: Payload

  public init(
    id: NodeID = NodeID(),
    parentId: ParentId,
    createdAt: Date = Date(),
    payload: Payload
  ) {
    self.id = id
    self.parentId = parentId
    self.createdAt = createdAt
    self.payload = payload
  }
}
