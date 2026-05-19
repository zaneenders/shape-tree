import Foundation

public enum TodoCompletionPolicy {
  /// A node is settled when it is completed/archived, or when it is an open parent whose
  /// direct children are all settled (recursive).
  public static func isSettled(
    itemID: String,
    items: [(id: String, parentNodeID: String?, status: TodoItemStatus)]
  ) -> Bool {
    guard let item = items.first(where: { $0.id == itemID }) else { return true }
    switch item.status {
    case .completed, .archive:
      return true
    case .open:
      let children = items.filter { $0.parentNodeID == itemID }
      guard !children.isEmpty else { return false }
      return children.allSatisfy { isSettled(itemID: $0.id, items: items) }
    }
  }

  /// A parent may be marked `completed` only when every direct child is settled.
  public static func canMarkCompleted(
    parentID: String,
    items: [(id: String, parentNodeID: String?, status: TodoItemStatus)]
  ) -> Bool {
    let children = items.filter { $0.parentNodeID == parentID }
    guard !children.isEmpty else { return true }
    return children.allSatisfy { isSettled(itemID: $0.id, items: items) }
  }

  public static func openChildCount(
    parentID: String,
    items: [(id: String, parentNodeID: String?, status: TodoItemStatus)]
  ) -> Int {
    items.filter { $0.parentNodeID == parentID && !isSettled(itemID: $0.id, items: items) }.count
  }
}
