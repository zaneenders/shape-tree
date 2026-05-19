import Foundation

public enum NodeTreeError: Error, Sendable, Equatable, CustomStringConvertible {
  case duplicateNodeID(NodeID)
  case parentNotFound(NodeID)
  case noRoot
  case multipleRoots
  case cycle(NodeID)
  case emptyGraph
  case invalidDataDirectoryName(String)

  public var description: String {
    switch self {
    case .duplicateNodeID(let id):
      "Duplicate node id '\(id)'."
    case .parentNotFound(let id):
      "Parent node '\(id)' does not exist."
    case .noRoot:
      "Tree must have a root node."
    case .multipleRoots:
      "Tree must have exactly one root node."
    case .cycle(let id):
      "Tree contains a cycle involving '\(id)'."
    case .emptyGraph:
      "Tree has no nodes."
    case .invalidDataDirectoryName(let name):
      "Invalid data directory name '\(name)'; use a single path component such as '.todo-tree'."
    }
  }
}

extension NodeTreeError: LocalizedError {
  public var errorDescription: String? { description }
}
