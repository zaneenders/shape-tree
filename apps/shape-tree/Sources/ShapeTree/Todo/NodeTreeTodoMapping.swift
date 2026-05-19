import Foundation
import NodeTree
import NodeTreeAPI

enum NodeTreeTodoMapping {

  static func resolvedTreeName(from queryTree: String?) -> String {
    let trimmed = queryTree?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? ShapeTreeDataLayout.defaultTodoTreeName : trimmed
  }

  /// Server-only anchor node; never returned from the public todo API.
  static func isUserVisible(
    _ node: TreeNode<TodoItemPayload>,
    canonicalRootID: NodeID
  ) -> Bool {
    if node.id == canonicalRootID { return false }
    if case .root = node.parentId { return false }
    if node.payload.title == "." { return false }
    if node.payload.title == "Todos" {
      if case .node(let parent) = node.parentId, parent == canonicalRootID { return false }
      if case .root = node.parentId { return false }
    }
    return true
  }

  static func resolveParentID(
    from api: Components.Schemas.ParentId,
    canonicalRootID: NodeID
  ) throws -> ParentId {
    switch api {
    case .root:
      return .node(canonicalRootID)
    case .node(let link):
      guard let uuid = UUID(uuidString: link.id) else {
        throw MappingError.invalidNodeID(link.id)
      }
      let parent = NodeID(rawValue: uuid)
      if parent == canonicalRootID {
        return .node(canonicalRootID)
      }
      return .node(parent)
    }
  }

  static func apiParentID(
    from node: ParentId,
    canonicalRootID: NodeID
  ) -> Components.Schemas.ParentId {
    switch node {
    case .root:
      return .root(.init(kind: .root))
    case .node(let id):
      if id == canonicalRootID {
        return .root(.init(kind: .root))
      }
      return .node(.init(kind: .node, id: id.rawValue.uuidString))
    }
  }

  static func apiStatus(from status: TodoItemStatus) -> Components.Schemas.TodoItemStatus {
    switch status {
    case .open: return .open
    case .completed: return .completed
    case .archive: return .archive
    }
  }

  static func payloadStatus(from api: Components.Schemas.TodoItemStatus?) -> TodoItemStatus {
    switch api {
    case .open, .none: return .open
    case .completed: return .completed
    case .archive: return .archive
    }
  }

  static func todoItem(
    from node: TreeNode<TodoItemPayload>,
    canonicalRootID: NodeID
  ) -> Components.Schemas.TodoItem {
    .init(
      id: node.id.rawValue.uuidString,
      parent_id: apiParentID(from: node.parentId, canonicalRootID: canonicalRootID),
      created_at: node.createdAt,
      title: node.payload.title,
      status: apiStatus(from: node.payload.status),
      notes: node.payload.notes
    )
  }

  static func userVisibleNodes(
    from nodes: [TreeNode<TodoItemPayload>],
    canonicalRootID: NodeID
  ) -> [TreeNode<TodoItemPayload>] {
    nodes.filter { isUserVisible($0, canonicalRootID: canonicalRootID) }
  }

  static func payload(from request: Components.Schemas.CreateTodoItemRequest) -> TodoItemPayload {
    .init(
      title: request.title,
      status: payloadStatus(from: request.status),
      notes: request.notes
    )
  }

  static func nodeID(from pathID: String) throws -> NodeID {
    guard let uuid = UUID(uuidString: pathID) else {
      throw MappingError.invalidNodeID(pathID)
    }
    return NodeID(rawValue: uuid)
  }

  static func mergedPayload(
    existing: TodoItemPayload,
    from request: Components.Schemas.UpdateTodoItemRequest
  ) -> TodoItemPayload {
    TodoItemPayload(
      title: request.title ?? existing.title,
      status: request.status.map { payloadStatus(from: $0) } ?? existing.status,
      notes: request.notes ?? existing.notes
    )
  }

  static func policyRows(
    from nodes: [TreeNode<TodoItemPayload>],
    canonicalRootID: NodeID
  ) -> [(
    id: String, parentNodeID: String?, status: TodoItemStatus
  )] {
    userVisibleNodes(from: nodes, canonicalRootID: canonicalRootID).map { node in
      let parentNodeID: String? = {
        if case .node(let parent) = node.parentId { return parent.rawValue.uuidString }
        return nil
      }()
      return (node.id.rawValue.uuidString, parentNodeID, node.payload.status)
    }
  }

  static func validateCanComplete(
    itemID: NodeID,
    newStatus: TodoItemStatus,
    nodes: [TreeNode<TodoItemPayload>],
    canonicalRootID: NodeID
  ) throws {
    guard newStatus == .completed else { return }
    let idString = itemID.rawValue.uuidString
    let openCount = TodoCompletionPolicy.openChildCount(
      parentID: idString,
      items: policyRows(from: nodes, canonicalRootID: canonicalRootID)
    )
    guard openCount == 0 else {
      throw NodeTreeError.parentCannotComplete(itemID, openChildCount: openCount)
    }
  }

  static func errorCode(for error: NodeTreeError) -> String {
    switch error {
    case .duplicateNodeID:
      "duplicate_node_id"
    case .parentNotFound:
      "parent_not_found"
    case .nodeNotFound:
      "not_found"
    case .noRoot:
      "no_root"
    case .multipleRoots:
      "multiple_roots"
    case .cycle:
      "cycle"
    case .emptyGraph:
      "empty_graph"
    case .invalidDataDirectoryName:
      "invalid_data_directory_name"
    case .parentCannotComplete:
      "parent_cannot_complete"
    }
  }

  enum MappingError: Error {
    case invalidNodeID(String)
  }
}
