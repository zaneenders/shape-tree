import Foundation

/// In-memory todo tree: each node has at most one parent; exactly one root; no cycles.
public struct TodoTreeGraph: Sendable, Equatable {
  private var nodesByID: [TodoNodeID: TodoNode]
  private var storedRootID: TodoNodeID?

  /// Empty graph for store bootstrap before the root is seeded.
  init() {
    nodesByID = [:]
    storedRootID = nil
  }

  public init(seedRootTitle: String) throws {
    self.init()
    _ = try seedRoot(title: seedRootTitle)
  }

  public init(nodes: [TodoNode]) throws {
    var byID: [TodoNodeID: TodoNode] = [:]
    byID.reserveCapacity(nodes.count)
    for node in nodes {
      guard byID[node.id] == nil else {
        throw TodoTreeError.duplicateNodeID(node.id)
      }
      byID[node.id] = node
    }
    self.nodesByID = byID
    self.storedRootID = try Self.singleRootID(in: byID)
    try validate()
  }

  public func rootID() throws -> TodoNodeID {
    if let storedRootID { return storedRootID }
    return try Self.singleRootID(in: nodesByID)
  }

  public var isEmpty: Bool { nodesByID.isEmpty }

  public var nodeCount: Int { nodesByID.count }

  public func node(id: TodoNodeID) -> TodoNode? {
    nodesByID[id]
  }

  public func root() throws -> TodoNode? {
    guard !nodesByID.isEmpty else { return nil }
    return nodesByID[try rootID()]
  }

  public func children(of parentID: TodoNodeID) -> [TodoNode] {
    nodesByID.values.filter { $0.parentId == .node(parentID) }.sorted(by: Self.stableOrder)
  }

  /// Validates invariants and returns nodes in topological order (every parent before its children).
  public func topologicalSort() throws -> [TodoNode] {
    try validate()
    guard !nodesByID.isEmpty else { return [] }

    var childrenByParent: [TodoNodeID: [TodoNodeID]] = [:]
    for node in nodesByID.values {
      guard case .node(let parentID) = node.parentId else { continue }
      childrenByParent[parentID, default: []].append(node.id)
    }
    for key in childrenByParent.keys {
      childrenByParent[key]?.sort { lhs, rhs in
        Self.stableOrder(nodesByID[lhs]!, nodesByID[rhs]!)
      }
    }

    var ordered: [TodoNode] = []
    ordered.reserveCapacity(nodesByID.count)

    func visit(_ id: TodoNodeID) {
      guard let node = nodesByID[id] else { return }
      ordered.append(node)
      for childID in childrenByParent[id] ?? [] {
        visit(childID)
      }
    }

    visit(try rootID())
    return ordered
  }

  mutating func seedRoot(title: String) throws -> TodoNode {
    guard nodesByID.isEmpty else {
      preconditionFailure("seedRoot requires an empty graph")
    }
    let root = TodoNode(title: try Self.normalizedTitle(title), parentId: .root)
    nodesByID[root.id] = root
    storedRootID = root.id
    try validate()
    return root
  }

  public mutating func insertNode(title: String, parentId: ParentId) throws -> TodoNode {
    let resolvedParentId = try resolveParentId(parentId)
    let node = TodoNode(title: try Self.normalizedTitle(title), parentId: resolvedParentId)
    nodesByID[node.id] = node
    try validate()
    return node
  }

  private func resolveParentId(_ parentId: ParentId) throws -> ParentId {
    switch parentId {
    case .root:
      return .node(try rootID())
    case .node(let parentID):
      guard nodesByID[parentID] != nil else {
        throw TodoTreeError.parentNotFound(parentID)
      }
      return parentId
    }
  }

  func allNodes() -> [TodoNode] {
    nodesByID.values.sorted(by: Self.stableOrder)
  }

  func validate() throws {
    guard !nodesByID.isEmpty else { return }

    let roots = nodesByID.values.filter { $0.parentId == .root }
    switch roots.count {
    case 0:
      throw TodoTreeError.noRoot
    case 1:
      break
    default:
      throw TodoTreeError.multipleRoots
    }

    if let storedRootID {
      guard roots[0].id == storedRootID else {
        throw TodoTreeError.multipleRoots
      }
    }

    for node in nodesByID.values {
      if case .node(let parentID) = node.parentId {
        guard nodesByID[parentID] != nil else {
          throw TodoTreeError.parentNotFound(parentID)
        }
      }
      if hasCycle(startingAt: node.id) {
        throw TodoTreeError.cycle(node.id)
      }
    }
  }

  private static func singleRootID(in nodes: [TodoNodeID: TodoNode]) throws -> TodoNodeID {
    let roots = nodes.values.filter { $0.parentId == .root }
    switch roots.count {
    case 1:
      return roots[0].id
    case 0:
      throw TodoTreeError.noRoot
    default:
      throw TodoTreeError.multipleRoots
    }
  }

  private func hasCycle(startingAt id: TodoNodeID) -> Bool {
    var visited: Set<TodoNodeID> = []
    var current: TodoNodeID? = id
    while let nodeID = current {
      guard visited.insert(nodeID).inserted else { return true }
      current = nodesByID[nodeID]?.parentId.parentNodeID
    }
    return false
  }

  private static func normalizedTitle(_ title: String) throws -> String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw TodoTreeError.emptyTitle }
    return trimmed
  }

  private static func stableOrder(_ lhs: TodoNode, _ rhs: TodoNode) -> Bool {
    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
    return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
  }
}
