import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import NodeTreeAPI
import OpenAPIAsyncHTTPClient
import ShapeTreeClient
import Testing
import _NIOFileSystem

@testable import ShapeTree

@Suite
struct TodoRouterTests {

  private var jsonDecoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  // MARK: - Auth

  @Test func rejectsMissingAuthorizationOnTodoRoutes() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let layout = ShapeTreeDataLayout(dataRoot: URL(fileURLWithPath: path.description, isDirectory: true))
      try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)
      let todoService = JournalTestFixtures.todoTreeService(layout: layout)
      let store = SessionStore()
      let log = Logger(label: "test.todo-jwt-missing")
      let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
      let fixture = try await JWTTestSupport.makeFixture()
      let router = try buildRoutes(
        store: store,
        journalStore: journal,
        authorizedKeys: fixture.store,
        todoTreeService: todoService,
        log: log,
        llmURL: "http://localhost:11434",
        agentModel: "test-model",
        systemPrompt: "You are a test assistant.",
        llmToken: nil,
        contextWindow: 8192,
        contextWindowThreshold: 0.8,
        workingDirectory: path.description
      )
      let app = Application(router: router)

      try await app.test(.router) { client in
        try await client.execute(uri: "/todo/items", method: .get) { response in
          #expect(response.status == .unauthorized)
        }
      }
    }
  }

  // MARK: - Todo CRUD

  @Test func createAndListTodoItemsBehindJWT() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let layout = ShapeTreeDataLayout(dataRoot: URL(fileURLWithPath: path.description, isDirectory: true))
      try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)
      let todoService = JournalTestFixtures.todoTreeService(layout: layout)
      let store = SessionStore()
      let log = Logger(label: "test.todo-crud")
      let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
      let fixture = try await JWTTestSupport.makeFixture()
      let router = try buildRoutes(
        store: store,
        journalStore: journal,
        authorizedKeys: fixture.store,
        todoTreeService: todoService,
        log: log,
        llmURL: "http://localhost:11434",
        agentModel: "test-model",
        systemPrompt: "You are a test assistant.",
        llmToken: nil,
        contextWindow: 8192,
        contextWindowThreshold: 0.8,
        workingDirectory: path.description
      )
      let app = Application(router: router)

      try await app.test(.router) { client in
        try await client.execute(
          uri: "/todo/root",
          method: .get,
          headers: try JWTTestSupport.bearerHeaders(fixture)
        ) { response in
          #expect(response.status == .notFound)
        }

        try await client.execute(
          uri: "/todo/items",
          method: .post,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(string: #"{"title":"write tests","parent_id":{"kind":"root"}}"#)
        ) { response in
          #expect(response.status == .created)
          let created = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.TodoItem.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          #expect(created.title == "write tests")
          #expect(created.status == .open)
        }

        try await client.execute(
          uri: "/todo/items",
          method: .get,
          headers: try JWTTestSupport.bearerHeaders(fixture)
        ) { response in
          #expect(response.status == .ok)
          let list = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.TodoItemListResponse.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          #expect(list.tree == "todo-tree")
          #expect(list.items.count == 1)
          #expect(list.items.map(\.title) == ["write tests"])
          if case .root = list.items[0].parent_id {
          } else {
            Issue.record("Expected top-level parent_id.kind == root")
          }
        }
      }
    }
  }

  @Test func listTodoItemChildrenBehindJWT() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let layout = ShapeTreeDataLayout(dataRoot: URL(fileURLWithPath: path.description, isDirectory: true))
      try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)
      let todoService = JournalTestFixtures.todoTreeService(layout: layout)
      let store = SessionStore()
      let log = Logger(label: "test.todo-children")
      let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
      let fixture = try await JWTTestSupport.makeFixture()
      let router = try buildRoutes(
        store: store,
        journalStore: journal,
        authorizedKeys: fixture.store,
        todoTreeService: todoService,
        log: log,
        llmURL: "http://localhost:11434",
        agentModel: "test-model",
        systemPrompt: "You are a test assistant.",
        llmToken: nil,
        contextWindow: 8192,
        contextWindowThreshold: 0.8,
        workingDirectory: path.description
      )
      let app = Application(router: router)

      try await app.test(.router) { client in
        var parentID = ""
        try await client.execute(
          uri: "/todo/items",
          method: .post,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(string: #"{"title":"parent","parent_id":{"kind":"root"}}"#)
        ) { response in
          #expect(response.status == .created)
          let parent = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.TodoItem.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          parentID = parent.id
        }

        try await client.execute(
          uri: "/todo/items",
          method: .post,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(string: #"{"title":"child","parent_id":{"kind":"node","id":"\#(parentID)"}}"#)
        ) { response in
          #expect(response.status == .created)
        }

        try await client.execute(
          uri: "/todo/items/\(parentID)/children",
          method: .get,
          headers: try JWTTestSupport.bearerHeaders(fixture)
        ) { response in
          #expect(response.status == .ok)
          let list = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.TodoItemListResponse.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          #expect(list.items.count == 1)
          #expect(list.items[0].title == "child")
        }
      }
    }
  }

  @Test func createTodoItemReturns404ForMissingParent() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let layout = ShapeTreeDataLayout(dataRoot: URL(fileURLWithPath: path.description, isDirectory: true))
      try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)
      let todoService = JournalTestFixtures.todoTreeService(layout: layout)
      let store = SessionStore()
      let log = Logger(label: "test.todo-parent-missing")
      let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
      let fixture = try await JWTTestSupport.makeFixture()
      let router = try buildRoutes(
        store: store,
        journalStore: journal,
        authorizedKeys: fixture.store,
        todoTreeService: todoService,
        log: log,
        llmURL: "http://localhost:11434",
        agentModel: "test-model",
        systemPrompt: "You are a test assistant.",
        llmToken: nil,
        contextWindow: 8192,
        contextWindowThreshold: 0.8,
        workingDirectory: path.description
      )
      let app = Application(router: router)
      let missing = UUID()

      try await app.test(.router) { client in
        try await client.execute(
          uri: "/todo/items",
          method: .post,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(string: #"{"title":"orphan","parent_id":{"kind":"node","id":"\#(missing.uuidString)"}}"#)
        ) { response in
          #expect(response.status == .notFound)
          let error = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.HTTPErrorResponse.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          #expect(error.error.code == "parent_not_found")
        }
      }
    }
  }

  @Test func parentCannotCompleteWhileChildrenOpen() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let layout = ShapeTreeDataLayout(dataRoot: URL(fileURLWithPath: path.description, isDirectory: true))
      try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)
      let todoService = JournalTestFixtures.todoTreeService(layout: layout)
      let store = SessionStore()
      let log = Logger(label: "test.todo-parent-complete")
      let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
      let fixture = try await JWTTestSupport.makeFixture()
      let router = try buildRoutes(
        store: store,
        journalStore: journal,
        authorizedKeys: fixture.store,
        todoTreeService: todoService,
        log: log,
        llmURL: "http://localhost:11434",
        agentModel: "test-model",
        systemPrompt: "You are a test assistant.",
        llmToken: nil,
        contextWindow: 8192,
        contextWindowThreshold: 0.8,
        workingDirectory: path.description
      )
      let app = Application(router: router)

      try await app.test(.router) { client in
        var parentID = ""
        try await client.execute(
          uri: "/todo/items",
          method: .post,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(string: #"{"title":"parent","parent_id":{"kind":"root"}}"#)
        ) { response in
          #expect(response.status == .created)
          let created = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.TodoItem.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          parentID = created.id
        }

        try await client.execute(
          uri: "/todo/items",
          method: .post,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(
            string: #"{"title":"child","parent_id":{"kind":"node","id":"\#(parentID)"}}"#)
        ) { response in
          #expect(response.status == .created)
        }

        try await client.execute(
          uri: "/todo/items/\(parentID)",
          method: .patch,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(string: #"{"status":"completed"}"#)
        ) { response in
          #expect(response.status == .conflict)
          let error = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.HTTPErrorResponse.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          #expect(error.error.code == "parent_cannot_complete")
        }
      }
    }
  }

  @Test func breakDownTodoItemCreatesChildren() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let layout = ShapeTreeDataLayout(dataRoot: URL(fileURLWithPath: path.description, isDirectory: true))
      try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)
      let todoService = JournalTestFixtures.todoTreeService(layout: layout)
      let store = SessionStore()
      let log = Logger(label: "test.todo-break-down")
      let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
      let fixture = try await JWTTestSupport.makeFixture()
      let router = try buildRoutes(
        store: store,
        journalStore: journal,
        authorizedKeys: fixture.store,
        todoTreeService: todoService,
        log: log,
        llmURL: "http://localhost:11434",
        agentModel: "test-model",
        systemPrompt: "You are a test assistant.",
        llmToken: nil,
        contextWindow: 8192,
        contextWindowThreshold: 0.8,
        workingDirectory: path.description
      )
      let app = Application(router: router)

      try await app.test(.router) { client in
        var parentID = ""
        try await client.execute(
          uri: "/todo/items",
          method: .post,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(string: #"{"title":"ship feature","parent_id":{"kind":"root"}}"#)
        ) { response in
          let created = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.TodoItem.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          parentID = created.id
        }

        try await client.execute(
          uri: "/todo/items/\(parentID)/break-down",
          method: .post,
          headers: try JWTTestSupport.bearerHeaders(fixture),
          body: ByteBuffer(string: #"{"steps":[{"title":"design"},{"title":"implement"}]}"#)
        ) { response in
          #expect(response.status == .created)
          let list = try jsonDecoder.decode(
            NodeTreeAPI.Components.Schemas.TodoItemListResponse.self,
            from: response.body.withUnsafeReadableBytes { Data($0) }
          )
          #expect(list.items.map(\.title) == ["design", "implement"])
        }
      }
    }
  }

  @Test func todoOpenAPIClientRoundTripBehindJWT() async throws {
    try await FileSystem.shared.withTemporaryDirectory { _, path in
      let layout = ShapeTreeDataLayout(dataRoot: URL(fileURLWithPath: path.description, isDirectory: true))
      try ShapeTreeDataLayout.bootstrapIfNeeded(layout: layout)
      let todoService = JournalTestFixtures.todoTreeService(layout: layout)
      let store = SessionStore()
      let log = Logger(label: "test.todo-openapi-client")
      let (journal, _) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
      let fixture = try await JWTTestSupport.makeFixture()
      let router = try buildRoutes(
        store: store,
        journalStore: journal,
        authorizedKeys: fixture.store,
        todoTreeService: todoService,
        log: log,
        llmURL: "http://localhost:11434",
        agentModel: "test-model",
        systemPrompt: "You are a test assistant.",
        llmToken: nil,
        contextWindow: 8192,
        contextWindowThreshold: 0.8,
        workingDirectory: path.description
      )
      let app = Application(router: router)

      try await app.test(.live) { client in
        let port = try #require(client.port, "Expected live server to have a port")
        let transport = AsyncHTTPClientTransport()
        let baseURL = URL(string: "http://localhost:\(port)")!

        let createClient = NodeTreeAPI.Client(
          serverURL: baseURL,
          transport: transport,
          middlewares: [BearerAuthClientMiddleware(bearerToken: try JWTTestSupport.mintToken(fixture))]
        )
        let created = try await createClient.createTodoItem(
          body: .json(
            .init(
              title: "from client",
              parent_id: .root(.init(kind: .root))
            )))
        let item = try created.created.body.json
        #expect(item.title == "from client")

        let listClient = NodeTreeAPI.Client(
          serverURL: baseURL,
          transport: transport,
          middlewares: [BearerAuthClientMiddleware(bearerToken: try JWTTestSupport.mintToken(fixture))]
        )
        let listed = try await listClient.listTodoItems()
        let list = try listed.ok.body.json
        #expect(list.items.contains { $0.id == item.id })
      }
    }
  }
}
