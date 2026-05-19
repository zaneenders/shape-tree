import NodeTree
import Testing

@Suite
struct NodeTreeGraphTests {

  @Test func seededRootSortsAlone() throws {
    let graph = try NodeTreeGraph(seedRootPayload: TitlePayload(title: "root"))
    let rootID = try graph.rootID()
    #expect(try graph.topologicalSort().map(\.id) == [rootID])
  }

  @Test func insertNodeTopologicalOrder() throws {
    var graph = try NodeTreeGraph(seedRootPayload: TitlePayload(title: "root"))
    let rootID = try graph.rootID()
    let child = try graph.insertNode(payload: TitlePayload(title: "child"), parentId: .root)
    let grandchild = try graph.insertNode(
      payload: TitlePayload(title: "grandchild"),
      parentId: .node(child.id)
    )

    let ordered = try graph.topologicalSort()
    #expect(ordered.map(\.id) == [rootID, child.id, grandchild.id])
  }

  @Test func rejectsMissingParent() throws {
    var graph = try NodeTreeGraph(seedRootPayload: TitlePayload(title: "root"))
    let missing = NodeID()
    #expect(throws: NodeTreeError.parentNotFound(missing)) {
      try graph.insertNode(payload: TitlePayload(title: "child"), parentId: .node(missing))
    }
  }

  @Test func insertUnderRootStoresParentAsNodeID() throws {
    var graph = try NodeTreeGraph(seedRootPayload: TitlePayload(title: "root"))
    let rootID = try graph.rootID()
    let child = try graph.insertNode(payload: TitlePayload(title: "child"), parentId: .root)
    #expect(child.parentId == .node(rootID))
  }

  @Test func rejectsCycleWhenLoading() throws {
    let root = TreeNode(parentId: .root, payload: TitlePayload(title: "root"))
    let a = TreeNode(parentId: .node(root.id), payload: TitlePayload(title: "a"))
    let b = TreeNode(parentId: .node(a.id), payload: TitlePayload(title: "b"))
    let cyclicA = TreeNode(
      id: a.id,
      parentId: .node(b.id),
      createdAt: a.createdAt,
      payload: a.payload
    )
    do {
      _ = try NodeTreeGraph(nodes: [root, cyclicA, b])
      Issue.record("Expected NodeTreeError.cycle")
    } catch let error as NodeTreeError {
      if case .cycle = error { return }
      Issue.record("Expected cycle, got \(error)")
    } catch {
      Issue.record("Expected NodeTreeError, got \(error)")
    }
  }

  @Test func rejectsDuplicateIDsWhenLoading() throws {
    let node = TreeNode(parentId: .root, payload: TitlePayload(title: "one"))
    #expect(throws: NodeTreeError.duplicateNodeID(node.id)) {
      try NodeTreeGraph(nodes: [node, node])
    }
  }

  @Test func rejectsMultipleRootsWhenLoading() throws {
    let rootA = TreeNode(parentId: .root, payload: TitlePayload(title: "a"))
    let rootB = TreeNode(parentId: .root, payload: TitlePayload(title: "b"))
    #expect(throws: NodeTreeError.multipleRoots) {
      try NodeTreeGraph(nodes: [rootA, rootB])
    }
  }

  @Test func adoptLoadedNodesRepairsMultipleRoots() throws {
    let rootA = TreeNode(parentId: .root, payload: TitlePayload(title: "Todos"))
    let rootB = TreeNode(parentId: .root, payload: TitlePayload(title: "Todos"))
    var graph = NodeTreeGraph<TitlePayload>()
    try graph.adoptLoadedNodes([rootA, rootB])
    #expect(try graph.normalizeToSingleRoot())
    let roots = try graph.topologicalSort().filter {
      if case .root = $0.parentId { return true }
      return false
    }
    #expect(roots.count == 1)
  }

}
