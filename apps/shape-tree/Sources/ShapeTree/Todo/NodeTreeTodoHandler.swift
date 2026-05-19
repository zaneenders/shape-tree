import Foundation
import Logging
import NodeTree
import NodeTreeAPI
import OpenAPIHummingbird
import OpenAPIRuntime

/// OpenAPI handlers for `/todo/*`, backed by ``NodeTreeStore`` via ``TodoTreeService``.
struct NodeTreeTodoHandler: APIProtocol, Sendable {
  let service: TodoTreeService
  let log: Logger

  private static func errorBody(_ message: String, code: String? = nil) -> Components.Schemas.HTTPErrorResponse {
    .init(error: .init(message: message, code: code))
  }

  private func internalErrorBody(event: String, _ error: Error, public publicMessage: String)
    -> Components.Schemas.HTTPErrorResponse
  {
    log.error("event=\(event) error=\(error.localizedDescription)")
    return Self.errorBody(publicMessage)
  }

  private func treeName<S: Sendable>(from query: S) -> String where S: TodoTreeNameQuery {
    NodeTreeTodoMapping.resolvedTreeName(from: query.tree)
  }

  private func openStore(tree: String) async throws -> (NodeTreeStore<TodoItemPayload>, NodeID) {
    let store = try await service.store(dataDirectoryName: tree)
    let rootID = try await store.canonicalRootID()
    return (store, rootID)
  }

  // MARK: GET /todo/root

  func getTodoRoot(_ input: Operations.getTodoRoot.Input) async throws -> Operations.getTodoRoot.Output {
    _ = treeName(from: input.query)
    return .notFound(
      .init(
        body: .json(
          Self.errorBody(
            "The tree root is managed by the server and is not exposed.",
            code: "not_visible"
          ))))
  }

  // MARK: GET /todo/items

  func listTodoItems(_ input: Operations.listTodoItems.Input) async throws -> Operations.listTodoItems.Output {
    let tree = treeName(from: input.query)
    do {
      let (store, rootID) = try await openStore(tree: tree)
      let nodes = try await store.topologicalSort()
      let items = NodeTreeTodoMapping.userVisibleNodes(from: nodes, canonicalRootID: rootID).map {
        NodeTreeTodoMapping.todoItem(from: $0, canonicalRootID: rootID)
      }
      return .ok(.init(body: .json(.init(tree: tree, items: items))))
    } catch let error as NodeTreeError {
      return nodeTreeErrorOutput(error)
    } catch {
      return .internalServerError(
        .init(
          body: .json(internalErrorBody(event: "todo.items.list.failure", error, public: "Failed to list todo items.")))
      )
    }
  }

  // MARK: POST /todo/items

  func createTodoItem(_ input: Operations.createTodoItem.Input) async throws -> Operations.createTodoItem.Output {
    guard case .json(let body) = input.body else {
      return .badRequest(.init(body: .json(Self.errorBody("Request body must be JSON."))))
    }

    let tree = treeName(from: input.query)
    let parentAPI = body.parent_id ?? .root(.init(kind: .root))
    let payload = NodeTreeTodoMapping.payload(from: body)
    if payload.status == .completed, let steps = body.steps, !steps.isEmpty {
      return .conflict(
        .init(
          body: .json(
            Self.errorBody(
              "Cannot create a completed item while inline steps would still be open.",
              code: "parent_cannot_complete"
            ))))
    }

    do {
      let (store, rootID) = try await openStore(tree: tree)
      let parentId = try NodeTreeTodoMapping.resolveParentID(from: parentAPI, canonicalRootID: rootID)
      let node = try await store.createNode(
        payload: payload,
        parentId: parentId
      )
      if let steps = body.steps {
        for step in steps {
          _ = try await store.createNode(
            payload: TodoItemPayload(title: step.title),
            parentId: .node(node.id)
          )
        }
      }
      if payload.status == .completed {
        let snapshot = try await store.topologicalSort()
        try NodeTreeTodoMapping.validateCanComplete(
          itemID: node.id,
          newStatus: .completed,
          nodes: snapshot,
          canonicalRootID: rootID
        )
      }
      let persisted = try await store.node(id: node.id) ?? node
      return .created(
        .init(body: .json(NodeTreeTodoMapping.todoItem(from: persisted, canonicalRootID: rootID))))
    } catch let error as NodeTreeError {
      return nodeTreeErrorOutput(error)
    } catch NodeTreeTodoMapping.MappingError.invalidNodeID(let id) {
      return .badRequest(.init(body: .json(Self.errorBody("Invalid node id '\(id)'.", code: "invalid_node_id"))))
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(event: "todo.items.create.failure", error, public: "Failed to create todo item."))))
    }
  }

  // MARK: GET /todo/items/{itemId}

  func getTodoItem(_ input: Operations.getTodoItem.Input) async throws -> Operations.getTodoItem.Output {
    let tree = treeName(from: input.query)
    do {
      let id = try NodeTreeTodoMapping.nodeID(from: input.path.itemId)
      let (store, rootID) = try await openStore(tree: tree)
      guard let node = try await store.node(id: id),
        NodeTreeTodoMapping.isUserVisible(node, canonicalRootID: rootID)
      else {
        return .notFound(.init(body: .json(Self.errorBody("Todo item not found.", code: "not_found"))))
      }
      return .ok(.init(body: .json(NodeTreeTodoMapping.todoItem(from: node, canonicalRootID: rootID))))
    } catch NodeTreeTodoMapping.MappingError.invalidNodeID(let id) {
      return .badRequest(.init(body: .json(Self.errorBody("Invalid item id '\(id)'.", code: "invalid_node_id"))))
    } catch let error as NodeTreeError {
      return nodeTreeErrorOutput(error)
    } catch {
      return .internalServerError(
        .init(
          body: .json(internalErrorBody(event: "todo.items.get.failure", error, public: "Failed to load todo item."))))
    }
  }

  // MARK: PATCH /todo/items/{itemId}

  func updateTodoItem(_ input: Operations.updateTodoItem.Input) async throws -> Operations.updateTodoItem.Output {
    guard case .json(let body) = input.body else {
      return .badRequest(.init(body: .json(Self.errorBody("Request body must be JSON."))))
    }

    let tree = treeName(from: input.query)
    do {
      let id = try NodeTreeTodoMapping.nodeID(from: input.path.itemId)
      let (store, rootID) = try await openStore(tree: tree)
      guard let existing = try await store.node(id: id),
        NodeTreeTodoMapping.isUserVisible(existing, canonicalRootID: rootID)
      else {
        return .notFound(.init(body: .json(Self.errorBody("Todo item not found.", code: "not_found"))))
      }
      let payload = NodeTreeTodoMapping.mergedPayload(existing: existing.payload, from: body)
      let snapshot = try await store.topologicalSort()
      try NodeTreeTodoMapping.validateCanComplete(
        itemID: id,
        newStatus: payload.status,
        nodes: snapshot,
        canonicalRootID: rootID
      )
      let node = try await store.updateNode(id: id, payload: payload)
      return .ok(.init(body: .json(NodeTreeTodoMapping.todoItem(from: node, canonicalRootID: rootID))))
    } catch NodeTreeTodoMapping.MappingError.invalidNodeID(let id) {
      return .badRequest(.init(body: .json(Self.errorBody("Invalid item id '\(id)'.", code: "invalid_node_id"))))
    } catch let error as NodeTreeError {
      return nodeTreeErrorOutput(error)
    } catch {
      return .internalServerError(
        .init(
          body: .json(internalErrorBody(event: "todo.items.update.failure", error, public: "Failed to update todo item."))))
    }
  }

  // MARK: POST /todo/items/{itemId}/break-down

  func breakDownTodoItem(
    _ input: Operations.breakDownTodoItem.Input
  ) async throws -> Operations.breakDownTodoItem.Output {
    guard case .json(let body) = input.body else {
      return .badRequest(.init(body: .json(Self.errorBody("Request body must be JSON."))))
    }

    let tree = treeName(from: input.query)
    do {
      let parentID = try NodeTreeTodoMapping.nodeID(from: input.path.itemId)
      let (store, rootID) = try await openStore(tree: tree)
      guard let parent = try await store.node(id: parentID),
        NodeTreeTodoMapping.isUserVisible(parent, canonicalRootID: rootID)
      else {
        return .notFound(.init(body: .json(Self.errorBody("Parent todo item not found.", code: "not_found"))))
      }
      var created: [Components.Schemas.TodoItem] = []
      for step in body.steps {
        let child = try await store.createNode(
          payload: TodoItemPayload(title: step.title),
          parentId: .node(parentID)
        )
        created.append(NodeTreeTodoMapping.todoItem(from: child, canonicalRootID: rootID))
      }
      return .created(.init(body: .json(.init(tree: tree, items: created))))
    } catch NodeTreeTodoMapping.MappingError.invalidNodeID(let id) {
      return .badRequest(.init(body: .json(Self.errorBody("Invalid item id '\(id)'.", code: "invalid_node_id"))))
    } catch let error as NodeTreeError {
      return nodeTreeErrorOutput(error)
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(
              event: "todo.items.break_down.failure",
              error,
              public: "Failed to break down todo item."
            ))))
    }
  }

  // MARK: GET /todo/items/{itemId}/children

  func listTodoItemChildren(
    _ input: Operations.listTodoItemChildren.Input
  ) async throws -> Operations.listTodoItemChildren.Output {
    let tree = treeName(from: input.query)
    do {
      let id = try NodeTreeTodoMapping.nodeID(from: input.path.itemId)
      let (store, rootID) = try await openStore(tree: tree)
      guard let parent = try await store.node(id: id) else {
        return .notFound(.init(body: .json(Self.errorBody("Parent todo item not found.", code: "not_found"))))
      }
      let childNodes: [TreeNode<TodoItemPayload>]
      if !NodeTreeTodoMapping.isUserVisible(parent, canonicalRootID: rootID) {
        childNodes = try await store.children(of: rootID)
      } else {
        childNodes = try await store.children(of: id)
      }
      let items = NodeTreeTodoMapping.userVisibleNodes(from: childNodes, canonicalRootID: rootID).map {
        NodeTreeTodoMapping.todoItem(from: $0, canonicalRootID: rootID)
      }
      return .ok(.init(body: .json(.init(tree: tree, items: items))))
    } catch NodeTreeTodoMapping.MappingError.invalidNodeID(let id) {
      return .badRequest(.init(body: .json(Self.errorBody("Invalid item id '\(id)'.", code: "invalid_node_id"))))
    } catch let error as NodeTreeError {
      return nodeTreeErrorOutput(error)
    } catch {
      return .internalServerError(
        .init(
          body: .json(
            internalErrorBody(
              event: "todo.items.children.failure",
              error,
              public: "Failed to list todo item children."
            ))))
    }
  }

  private func nodeTreeErrorOutput<E>(_ error: NodeTreeError) -> E where E: NodeTreeTodoErrorOutput {
    let code = NodeTreeTodoMapping.errorCode(for: error)
    switch error {
    case .parentNotFound, .nodeNotFound:
      return E.notFound(Self.errorBody(error.description, code: code))
    case .invalidDataDirectoryName:
      return E.badRequest(Self.errorBody(error.description, code: code))
    case .noRoot:
      return E.notFound(Self.errorBody(error.description, code: code))
    case .parentCannotComplete:
      return E.conflict(Self.errorBody(error.description, code: code))
    default:
      return E.internalServerError(Self.errorBody(error.description, code: code))
    }
  }
}

/// Query types that expose an optional `tree` parameter from the OpenAPI generator.
private protocol TodoTreeNameQuery {
  var tree: String? { get }
}

extension Operations.getTodoRoot.Input.Query: TodoTreeNameQuery {}
extension Operations.listTodoItems.Input.Query: TodoTreeNameQuery {}
extension Operations.createTodoItem.Input.Query: TodoTreeNameQuery {}
extension Operations.getTodoItem.Input.Query: TodoTreeNameQuery {}
extension Operations.updateTodoItem.Input.Query: TodoTreeNameQuery {}
extension Operations.listTodoItemChildren.Input.Query: TodoTreeNameQuery {}
extension Operations.breakDownTodoItem.Input.Query: TodoTreeNameQuery {}

/// Maps ``NodeTreeError`` cases onto each operation's generated ``Output`` enum.
private protocol NodeTreeTodoErrorOutput {
  static func badRequest(_ body: Components.Schemas.HTTPErrorResponse) -> Self
  static func notFound(_ body: Components.Schemas.HTTPErrorResponse) -> Self
  static func conflict(_ body: Components.Schemas.HTTPErrorResponse) -> Self
  static func internalServerError(_ body: Components.Schemas.HTTPErrorResponse) -> Self
}

extension Operations.getTodoRoot.Output: NodeTreeTodoErrorOutput {
  static func badRequest(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .badRequest(.init(body: .json(body)))
  }
  static func notFound(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .notFound(.init(body: .json(body)))
  }
  static func conflict(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
  static func internalServerError(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
}

extension Operations.listTodoItems.Output: NodeTreeTodoErrorOutput {
  static func badRequest(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .badRequest(.init(body: .json(body)))
  }
  static func notFound(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
  static func conflict(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
  static func internalServerError(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
}

extension Operations.createTodoItem.Output: NodeTreeTodoErrorOutput {
  static func badRequest(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .badRequest(.init(body: .json(body)))
  }
  static func notFound(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .notFound(.init(body: .json(body)))
  }
  static func conflict(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .conflict(.init(body: .json(body)))
  }
  static func internalServerError(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
}

extension Operations.getTodoItem.Output: NodeTreeTodoErrorOutput {
  static func badRequest(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .badRequest(.init(body: .json(body)))
  }
  static func notFound(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .notFound(.init(body: .json(body)))
  }
  static func conflict(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
  static func internalServerError(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
}

extension Operations.updateTodoItem.Output: NodeTreeTodoErrorOutput {
  static func badRequest(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .badRequest(.init(body: .json(body)))
  }
  static func notFound(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .notFound(.init(body: .json(body)))
  }
  static func conflict(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .conflict(.init(body: .json(body)))
  }
  static func internalServerError(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
}

extension Operations.listTodoItemChildren.Output: NodeTreeTodoErrorOutput {
  static func badRequest(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .badRequest(.init(body: .json(body)))
  }
  static func notFound(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .notFound(.init(body: .json(body)))
  }
  static func conflict(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
  static func internalServerError(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
}

extension Operations.breakDownTodoItem.Output: NodeTreeTodoErrorOutput {
  static func badRequest(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .badRequest(.init(body: .json(body)))
  }
  static func notFound(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .notFound(.init(body: .json(body)))
  }
  static func conflict(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
  static func internalServerError(_ body: Components.Schemas.HTTPErrorResponse) -> Self {
    .internalServerError(.init(body: .json(body)))
  }
}
