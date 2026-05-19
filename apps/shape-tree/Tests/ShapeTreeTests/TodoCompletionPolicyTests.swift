import NodeTreeAPI
import Testing

@Test func settledTreatsArchivedChildAsDone() {
  let items: [(id: String, parentNodeID: String?, status: TodoItemStatus)] = [
    ("parent", nil, .open),
    ("child", "parent", .archive),
  ]
  #expect(TodoCompletionPolicy.isSettled(itemID: "child", items: items))
  #expect(TodoCompletionPolicy.canMarkCompleted(parentID: "parent", items: items))
}

@Test func settledWhenOpenParentHasOnlySettledDescendants() {
  let items: [(id: String, parentNodeID: String?, status: TodoItemStatus)] = [
    ("exercise", nil, .open),
    ("bike", "exercise", .open),
    ("buy", "bike", .completed),
    ("ride", "bike", .completed),
  ]
  #expect(TodoCompletionPolicy.isSettled(itemID: "bike", items: items))
  #expect(TodoCompletionPolicy.canMarkCompleted(parentID: "exercise", items: items))
}

@Test func unsettledWhenDirectChildStillOpen() {
  let items: [(id: String, parentNodeID: String?, status: TodoItemStatus)] = [
    ("parent", nil, .open),
    ("done", "parent", .completed),
    ("todo", "parent", .open),
  ]
  #expect(!TodoCompletionPolicy.canMarkCompleted(parentID: "parent", items: items))
  #expect(TodoCompletionPolicy.openChildCount(parentID: "parent", items: items) == 1)
}
