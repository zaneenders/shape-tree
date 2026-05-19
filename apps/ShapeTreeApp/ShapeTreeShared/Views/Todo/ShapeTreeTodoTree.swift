import Foundation
import NodeTreeAPI

struct ShapeTreeTodoDisplayNode: Identifiable, Sendable {
  var id: String { item.id }
  let item: ShapeTreeViewModel.TodoItem
  var children: [ShapeTreeTodoDisplayNode]

  /// `nil` when leaf — required by `OutlineGroup`.
  var outlineChildren: [ShapeTreeTodoDisplayNode]? {
    children.isEmpty ? nil : children
  }
}

enum ShapeTreeTodoTree {
  static func isArchived(_ item: ShapeTreeViewModel.TodoItem) -> Bool {
    item.status == .archive
  }

  /// Visible in the sidebar tree. Archived nodes appear only when `showArchived` is true.
  static func isVisibleInList(
    _ item: ShapeTreeViewModel.TodoItem,
    items: [ShapeTreeViewModel.TodoItem],
    showArchived: Bool
  ) -> Bool {
    if isArchived(item) { return showArchived }

    var current: ShapeTreeViewModel.TodoItem? = item
    while let node = current, case .node(let parent) = node.parent_id {
      guard let parentItem = items.first(where: { $0.id == parent.id }) else { return true }
      if isArchived(parentItem) { return false }
      current = parentItem
    }
    return true
  }

  static func isVisibleInActiveList(
    _ item: ShapeTreeViewModel.TodoItem,
    items: [ShapeTreeViewModel.TodoItem]
  ) -> Bool {
    isVisibleInList(item, items: items, showArchived: false)
  }

  static func activeItems(from items: [ShapeTreeViewModel.TodoItem]) -> [ShapeTreeViewModel.TodoItem] {
    items.filter { isVisibleInActiveList($0, items: items) }
  }

  static func archivedItems(from items: [ShapeTreeViewModel.TodoItem]) -> [ShapeTreeViewModel.TodoItem] {
    items
      .filter { item in
        if case .root = item.parent_id { return false }
        return isArchived(item)
      }
      .sorted { $0.created_at > $1.created_at }
  }

  static func roots(
    from items: [ShapeTreeViewModel.TodoItem],
    showArchived: Bool = false
  ) -> [ShapeTreeTodoDisplayNode] {
    roots(from: items, visible: { isVisibleInList($0, items: items, showArchived: showArchived) })
  }

  private static func roots(
    from items: [ShapeTreeViewModel.TodoItem],
    visible: (ShapeTreeViewModel.TodoItem) -> Bool
  ) -> [ShapeTreeTodoDisplayNode] {
    var childrenByParent: [String: [String]] = [:]
    for item in items where visible(item) {
      guard case .node(let parent) = item.parent_id else { continue }
      childrenByParent[parent.id, default: []].append(item.id)
    }
    for key in childrenByParent.keys {
      childrenByParent[key]?.sort { lhs, rhs in
        sortKey(for: lhs, in: items) < sortKey(for: rhs, in: items)
      }
    }

    let topLevelIDs =
      items
      .filter { visible($0) }
      .filter { if case .root = $0.parent_id { return true } else { return false } }
      .map(\.id)
      .sorted { sortKey(for: $0, in: items) < sortKey(for: $1, in: items) }

    return topLevelIDs.compactMap {
      build(id: $0, items: items, childrenByParent: childrenByParent, visible: visible)
    }
  }

  static func parentID(for item: ShapeTreeViewModel.TodoItem) -> Components.Schemas.ParentId {
    switch item.parent_id {
    case .root:
      return .root(.init(kind: .root))
    case .node(let link):
      return .node(.init(kind: .node, id: link.id))
    }
  }

  private static func build(
    id: String,
    items: [ShapeTreeViewModel.TodoItem],
    childrenByParent: [String: [String]],
    visible: (ShapeTreeViewModel.TodoItem) -> Bool = { _ in true }
  ) -> ShapeTreeTodoDisplayNode? {
    guard let item = items.first(where: { $0.id == id }), visible(item) else { return nil }
    let childNodes = (childrenByParent[id] ?? []).compactMap {
      build(id: $0, items: items, childrenByParent: childrenByParent, visible: visible)
    }
    return ShapeTreeTodoDisplayNode(item: item, children: childNodes)
  }

  static func parentTitle(for item: ShapeTreeViewModel.TodoItem, in items: [ShapeTreeViewModel.TodoItem]) -> String? {
    guard case .node(let parent) = item.parent_id,
      let parentItem = items.first(where: { $0.id == parent.id })
    else { return nil }
    if case .root = parentItem.parent_id { return nil }
    return parentItem.title
  }

  private static func sortKey(for id: String, in items: [ShapeTreeViewModel.TodoItem]) -> Date {
    items.first(where: { $0.id == id })?.created_at ?? .distantPast
  }

  static func policyRows(
    from items: [ShapeTreeViewModel.TodoItem]
  ) -> [(id: String, parentNodeID: String?, status: TodoItemStatus)] {
    items.map { item in
      let parentNodeID: String? = {
        if case .node(let parent) = item.parent_id { return parent.id }
        return nil
      }()
      return (item.id, parentNodeID, payloadStatus(from: item.status))
    }
  }

  static func canMarkCompleted(itemID: String, items: [ShapeTreeViewModel.TodoItem]) -> Bool {
    TodoCompletionPolicy.canMarkCompleted(parentID: itemID, items: policyRows(from: items))
  }

  static func isSettledForRollup(
    _ item: ShapeTreeViewModel.TodoItem,
    items: [ShapeTreeViewModel.TodoItem]
  ) -> Bool {
    TodoCompletionPolicy.isSettled(itemID: item.id, items: policyRows(from: items))
  }

  static func hasChildren(itemID: String, items: [ShapeTreeViewModel.TodoItem]) -> Bool {
    !directChildren(parentID: itemID, items: items).isEmpty
  }

  static func directChildren(
    parentID: String,
    items: [ShapeTreeViewModel.TodoItem]
  ) -> [ShapeTreeViewModel.TodoItem] {
    items.filter { item in
      if case .node(let parent) = item.parent_id { return parent.id == parentID }
      return false
    }
  }

  static func sortedDirectChildren(
    parentID: String,
    items: [ShapeTreeViewModel.TodoItem]
  ) -> [ShapeTreeViewModel.TodoItem] {
    directChildren(parentID: parentID, items: items).sorted {
      ($0.created_at) < ($1.created_at)
    }
  }

  static func payloadStatus(from api: Components.Schemas.TodoItemStatus?) -> TodoItemStatus {
    switch api {
    case .open, .none: return .open
    case .completed: return .completed
    case .archive: return .archive
    }
  }

  static func apiStatus(from status: TodoItemStatus) -> Components.Schemas.TodoItemStatus {
    switch status {
    case .open: return .open
    case .completed: return .completed
    case .archive: return .archive
    }
  }
}
