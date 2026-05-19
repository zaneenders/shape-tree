import Foundation

public struct TodoNodeID: Hashable, Sendable, Codable, CustomStringConvertible {
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
  case node(TodoNodeID)
}

extension ParentId {
  public var parentNodeID: TodoNodeID? {
    guard case .node(let id) = self else { return nil }
    return id
  }
}

/// A single todo item positioned in a parent/child tree (``parentId`` is ``ParentId/root`` for the root).
public struct TodoNode: Sendable, Codable, Equatable, Identifiable {
  public var id: TodoNodeID
  public var title: String
  public var parentId: ParentId
  public var createdAt: Date

  public init(
    id: TodoNodeID = TodoNodeID(),
    title: String,
    parentId: ParentId,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.parentId = parentId
    self.createdAt = createdAt
  }
}
