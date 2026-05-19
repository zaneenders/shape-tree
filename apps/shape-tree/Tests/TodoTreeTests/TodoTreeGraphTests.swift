import Testing
import TodoTree

@Suite
struct TodoTreeGraphTests {

  @Test func seededRootSortsAlone() throws {
    let graph = try TodoTreeGraph(seedRootTitle: "root")
    let rootID = try graph.rootID()
    #expect(try graph.topologicalSort().map(\.id) == [rootID])
  }

  @Test func insertNodeTopologicalOrder() throws {
    var graph = try TodoTreeGraph(seedRootTitle: "root")
    let rootID = try graph.rootID()
    let child = try graph.insertNode(title: "child", parentId: .root)
    let grandchild = try graph.insertNode(title: "grandchild", parentId: .node(child.id))

    let ordered = try graph.topologicalSort()
    #expect(ordered.map(\.id) == [rootID, child.id, grandchild.id])
  }

  @Test func rejectsMissingParent() throws {
    var graph = try TodoTreeGraph(seedRootTitle: "root")
    let missing = TodoNodeID()
    #expect(throws: TodoTreeError.parentNotFound(missing)) {
      try graph.insertNode(title: "child", parentId: .node(missing))
    }
  }

  @Test func insertUnderRootStoresParentAsNodeID() throws {
    var graph = try TodoTreeGraph(seedRootTitle: "root")
    let rootID = try graph.rootID()
    let child = try graph.insertNode(title: "child", parentId: .root)
    #expect(child.parentId == .node(rootID))
  }

  @Test func rejectsEmptyTitleOnInsert() throws {
    var graph = try TodoTreeGraph(seedRootTitle: "root")
    let rootID = try graph.rootID()
    #expect(throws: TodoTreeError.emptyTitle) {
      try graph.insertNode(title: "   ", parentId: .node(rootID))
    }
  }

  @Test func rejectsCycleWhenLoading() throws {
    let root = TodoNode(title: "root", parentId: .root)
    let a = TodoNode(title: "a", parentId: .node(root.id))
    let b = TodoNode(title: "b", parentId: .node(a.id))
    let cyclicA = TodoNode(id: a.id, title: a.title, parentId: .node(b.id), createdAt: a.createdAt)
    do {
      _ = try TodoTreeGraph(nodes: [root, cyclicA, b])
      Issue.record("Expected TodoTreeError.cycle")
    } catch let error as TodoTreeError {
      if case .cycle = error { return }
      Issue.record("Expected cycle, got \(error)")
    } catch {
      Issue.record("Expected TodoTreeError, got \(error)")
    }
  }

  @Test func rejectsDuplicateIDsWhenLoading() throws {
    let node = TodoNode(title: "one", parentId: .root)
    #expect(throws: TodoTreeError.duplicateNodeID(node.id)) {
      try TodoTreeGraph(nodes: [node, node])
    }
  }

  @Test func rejectsMultipleRootsWhenLoading() throws {
    let rootA = TodoNode(title: "a", parentId: .root)
    let rootB = TodoNode(title: "b", parentId: .root)
    #expect(throws: TodoTreeError.multipleRoots) {
      try TodoTreeGraph(nodes: [rootA, rootB])
    }
  }
}
