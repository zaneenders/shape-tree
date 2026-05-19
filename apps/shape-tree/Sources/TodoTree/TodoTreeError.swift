import Foundation

public enum TodoTreeError: Error, Sendable, Equatable, CustomStringConvertible {
  case emptyTitle
  case duplicateNodeID(TodoNodeID)
  case parentNotFound(TodoNodeID)
  case noRoot
  case multipleRoots
  case cycle(TodoNodeID)
  case emptyGraph

  public var description: String {
    switch self {
    case .emptyTitle:
      "Todo title cannot be empty."
    case .duplicateNodeID(let id):
      "Duplicate todo node id '\(id)'."
    case .parentNotFound(let id):
      "Parent todo node '\(id)' does not exist."
    case .noRoot:
      "Todo tree must have a root node."
    case .multipleRoots:
      "Todo tree must have exactly one root node."
    case .cycle(let id):
      "Todo tree contains a cycle involving '\(id)'."
    case .emptyGraph:
      "Todo tree has no nodes."
    }
  }
}

extension TodoTreeError: LocalizedError {
  public var errorDescription: String? { description }
}
