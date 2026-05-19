import Foundation
import NodeTree
import NodeTreeAPI
import SystemPackage

/// Opens and caches ``NodeTreeStore`` instances under ``ShapeTreeDataLayout/nodeTreeWorkspace``.
actor TodoTreeService {
  let layout: ShapeTreeDataLayout
  private var stores: [String: NodeTreeStore<TodoItemPayload>] = [:]

  init(layout: ShapeTreeDataLayout) {
    self.layout = layout
  }

  func store(dataDirectoryName tree: String) async throws -> NodeTreeStore<TodoItemPayload> {
    if let cached = stores[tree] { return cached }
    let opened = try await NodeTreeStore.open(
      root: FilePath(layout.nodeTreeWorkspace.path),
      dataDirectoryName: tree,
      rootPayload: TodoItemPayload(title: ".")
    )
    stores[tree] = opened
    return opened
  }
}
