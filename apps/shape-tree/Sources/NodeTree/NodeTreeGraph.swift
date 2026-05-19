import Foundation

/// In-memory tree: each node has at most one parent; exactly one root; no cycles.
public struct NodeTreeGraph<Payload: Codable & Sendable>: Sendable {
  private var nodesByID: [NodeID: TreeNode<Payload>]
  private var storedRootID: NodeID?

  init() {
    nodesByID = [:]
    storedRootID = nil
  }

  public init(seedRootPayload: Payload) throws {
    self.init()
    _ = try seedRoot(payload: seedRootPayload)
  }

  public init(nodes: [TreeNode<Payload>]) throws {
    var byID: [NodeID: TreeNode<Payload>] = [:]
    byID.reserveCapacity(nodes.count)
    for node in nodes {
      guard byID[node.id] == nil else {
        throw NodeTreeError.duplicateNodeID(node.id)
      }
      byID[node.id] = node
    }
    self.nodesByID = byID
    self.storedRootID = try Self.singleRootID(in: byID)
    try validate()
  }

  public func rootID() throws -> NodeID {
    if let storedRootID { return storedRootID }
    return try Self.singleRootID(in: nodesByID)
  }

  public var isEmpty: Bool { nodesByID.isEmpty }

  public var nodeCount: Int { nodesByID.count }

  public func node(id: NodeID) -> TreeNode<Payload>? {
    nodesByID[id]
  }

  public func root() throws -> TreeNode<Payload>? {
    guard !nodesByID.isEmpty else { return nil }
    return nodesByID[try rootID()]
  }

  public func children(of parentID: NodeID) -> [TreeNode<Payload>] {
    nodesByID.values.filter { $0.parentId == .node(parentID) }.sorted(by: Self.stableOrder)
  }

  /// Validates invariants and returns nodes in topological order (every parent before its children).
  public func topologicalSort() throws -> [TreeNode<Payload>] {
    try validate()
    guard !nodesByID.isEmpty else { return [] }

    var childrenByParent: [NodeID: [NodeID]] = [:]
    for node in nodesByID.values {
      guard case .node(let parentID) = node.parentId else { continue }
      childrenByParent[parentID, default: []].append(node.id)
    }
    for key in childrenByParent.keys {
      childrenByParent[key]?.sort { lhs, rhs in
        Self.stableOrder(nodesByID[lhs]!, nodesByID[rhs]!)
      }
    }

    var ordered: [TreeNode<Payload>] = []
    ordered.reserveCapacity(nodesByID.count)

    func visit(_ id: NodeID) {
      guard let node = nodesByID[id] else { return }
      ordered.append(node)
      for childID in childrenByParent[id] ?? [] {
        visit(childID)
      }
    }

    visit(try rootID())
    return ordered
  }

  mutating func seedRoot(payload: Payload) throws -> TreeNode<Payload> {
    guard nodesByID.isEmpty else {
      preconditionFailure("seedRoot requires an empty graph")
    }
    let root = TreeNode(parentId: .root, payload: payload)
    nodesByID[root.id] = root
    storedRootID = root.id
    try validate()
    return root
  }

  public mutating func insertNode(payload: Payload, parentId: ParentId) throws -> TreeNode<Payload> {
    let resolvedParentId = try resolveParentId(parentId)
    let node = TreeNode(parentId: resolvedParentId, payload: payload)
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
        throw NodeTreeError.parentNotFound(parentID)
      }
      return parentId
    }
  }

  func allNodes() -> [TreeNode<Payload>] {
    nodesByID.values.sorted(by: Self.stableOrder)
  }

  func validate() throws {
    guard !nodesByID.isEmpty else { return }

    let roots = nodesByID.values.filter { $0.parentId == .root }
    switch roots.count {
    case 0:
      throw NodeTreeError.noRoot
    case 1:
      break
    default:
      throw NodeTreeError.multipleRoots
    }

    if let storedRootID {
      guard roots[0].id == storedRootID else {
        throw NodeTreeError.multipleRoots
      }
    }

    for node in nodesByID.values {
      if case .node(let parentID) = node.parentId {
        guard nodesByID[parentID] != nil else {
          throw NodeTreeError.parentNotFound(parentID)
        }
      }
      if hasCycle(startingAt: node.id) {
        throw NodeTreeError.cycle(node.id)
      }
    }
  }

  private static func singleRootID(in nodes: [NodeID: TreeNode<Payload>]) throws -> NodeID {
    let roots = nodes.values.filter { $0.parentId == .root }
    switch roots.count {
    case 1:
      return roots[0].id
    case 0:
      throw NodeTreeError.noRoot
    default:
      throw NodeTreeError.multipleRoots
    }
  }

  private func hasCycle(startingAt id: NodeID) -> Bool {
    var visited: Set<NodeID> = []
    var current: NodeID? = id
    while let nodeID = current {
      guard visited.insert(nodeID).inserted else { return true }
      current = nodesByID[nodeID]?.parentId.parentNodeID
    }
    return false
  }

  private static func stableOrder(_ lhs: TreeNode<Payload>, _ rhs: TreeNode<Payload>) -> Bool {
    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
    return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
  }
}
