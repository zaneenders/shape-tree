import NodeTreeAPI
import SwiftUI

enum ShapeTreeTodoDisplayStatus: String, Sendable {
  case open
  case inProgress
  case completed
  case archived

  var label: String {
    switch self {
    case .open: return "Open"
    case .inProgress: return "In progress"
    case .completed: return "Complete"
    case .archived: return "Archived"
    }
  }
}

enum ShapeTreeTodoStatusStyle {
  static func color(for status: ShapeTreeTodoDisplayStatus) -> Color {
    switch status {
    case .open:
      return Color(red: 1, green: 0.58, blue: 0.2)
    case .inProgress:
      return Color(red: 0.35, green: 0.78, blue: 1)
    case .completed:
      return Color(red: 0.3, green: 0.85, blue: 0.45)
    case .archived:
      return Color(white: 0.55)
    }
  }

  static func color(for apiStatus: ShapeTreeViewModel.TodoItemStatus?) -> Color {
    color(for: displayStatus(forAPIStatus: apiStatus, hasChildren: false))
  }

  static func displayStatus(
    for item: ShapeTreeViewModel.TodoItem,
    items: [ShapeTreeViewModel.TodoItem]
  ) -> ShapeTreeTodoDisplayStatus {
    if ShapeTreeTodoTree.isArchived(item) { return .archived }

    if ShapeTreeTodoTree.hasChildren(itemID: item.id, items: items) {
      return rollupStatus(parentID: item.id, items: items)
    }

    return displayStatus(forAPIStatus: item.status, hasChildren: false)
  }

  private static func displayStatus(
    forAPIStatus status: ShapeTreeViewModel.TodoItemStatus?,
    hasChildren: Bool
  ) -> ShapeTreeTodoDisplayStatus {
    switch status {
    case .open, .none:
      return hasChildren ? .inProgress : .open
    case .completed:
      return .completed
    case .archive:
      return .archived
    }
  }

  private static func rollupStatus(
    parentID: String,
    items: [ShapeTreeViewModel.TodoItem]
  ) -> ShapeTreeTodoDisplayStatus {
    let children = ShapeTreeTodoTree.directChildren(parentID: parentID, items: items)
    guard !children.isEmpty else { return .open }

    if children.allSatisfy(ShapeTreeTodoTree.isArchived) {
      return .archived
    }
    if children.allSatisfy({ ShapeTreeTodoTree.isSettledForRollup($0, items: items) }) {
      return .completed
    }
    return .inProgress
  }
}
