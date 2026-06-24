import Foundation
import Testing

@testable import ShapeTreeWebCore

@Suite struct ContentStoreTests {
  @Test func loadsWasmNodesFromDirectory() throws {
    let store = try Self.makeStore(nodes: [
      ("Home", "ShapeTree Web"),
      ("style-guide", "Style Guide"),
      ("notes/local-dev", "Local Dev"),
    ])

    #expect(store.nodes.count == 3)
    #expect(store.homeNode?.title == "ShapeTree Web")
    #expect(store.node(path: "style-guide")?.title == "Style Guide")
    #expect(store.publishedNodes.count == 2)
  }

  @Test func groupsNodesByDirectory() throws {
    let store = try Self.makeStore(nodes: [
      ("Home", "Home"),
      ("notes/local-dev", "Local Dev"),
      ("notes/style-guide", "Style Guide"),
      ("guides/getting-started", "Getting Started"),
    ])

    let groups = store.nodeGroups(includingPrivate: false)
    #expect(groups.contains { $0.directory == "notes" })
    #expect(groups.contains { $0.directory == "guides" })
    #expect(groups.first(where: { $0.directory == "notes" })?.nodes.count == 2)
  }

  @Test func hidesPrivateNodesWhenRequested() throws {
    let store = try Self.makeStore(
      nodes: [
        ("Home", "Home"),
        ("Public/post", "Public Post"),
        ("Private/secret", "Secret Post"),
      ],
      privateDirectories: ["Private"]
    )

    #expect(store.nodeGroups(includingPrivate: false).flatMap(\.nodes).contains { $0.path == "Public/post" })
    #expect(!store.nodeGroups(includingPrivate: false).flatMap(\.nodes).contains { $0.path == "Private/secret" })
    #expect(store.nodeGroups(includingPrivate: true).flatMap(\.nodes).contains { $0.path == "Private/secret" })
  }

  @Test func canViewFileRejectsPrivateDirectoryFilesWhenUnauthenticated() throws {
    let store = try Self.makeStore(
      nodes: [
        ("Home", "Home"),
        ("Private/secret", "Secret Post"),
      ],
      privateDirectories: ["Private"]
    )

    #expect(store.canViewFile(relativePath: "Private/secret.css", isAuthenticated: false) == false)
    #expect(store.canViewFile(relativePath: "Private/secret.css", isAuthenticated: true) == true)
    #expect(store.canViewFile(relativePath: "Home.css", isAuthenticated: false) == true)
    #expect(store.canViewFile(relativePath: "style.css", isAuthenticated: false) == true)
  }

  @Test func canViewFileRejectsNestedPrivateDirectoryFiles() throws {
    let store = try Self.makeStore(
      nodes: [
        ("Home", "Home"),
        ("Private/sub/secret", "Secret Post"),
      ],
      privateDirectories: ["Private"]
    )

    #expect(store.canViewFile(relativePath: "Private/sub/secret.css", isAuthenticated: false) == false)
    #expect(store.canViewFile(relativePath: "Private/sub/secret.css", isAuthenticated: true) == true)
  }

  @Test func canViewFileRejectsTraversalAndEmptyPaths() throws {
    let store = try Self.makeStore(nodes: [("Home", "Home")])

    #expect(store.canViewFile(relativePath: "", isAuthenticated: true) == false)
    #expect(store.canViewFile(relativePath: "../secret.css", isAuthenticated: true) == false)
  }

  @Test func navContentUsesContentURLs() throws {
    let store = try Self.makeStore(nodes: [
      ("Home", "ShapeTree Web"),
      ("Articles/demo", "Demo"),
    ])

    let payload = store.navContentResponse(viewer: NavViewer(isAuthenticated: false))
    #expect(payload.home.href == "/")
    #expect(payload.home.path == "Home")
    let demo = payload.groups.flatMap(\.items).first { $0.path == "Articles/demo" }
    #expect(demo?.href == "/content/Articles/demo")
  }

  @Test func hidesPrivateGroupsWhenUnauthenticated() throws {
    let store = try Self.makeStore(
      nodes: [
        ("Home", "Home"),
        ("Public", "Public Post"),
        ("Private/Secret", "Secret Post"),
      ],
      privateDirectories: ["Private"]
    )

    let response = store.navContentResponse(viewer: NavViewer(isAuthenticated: false))
    #expect(!response.groups.contains { $0.directory == "Private" })
    #expect(response.groups.flatMap(\.items).contains { $0.path == "Public" })
    #expect(!response.groups.flatMap(\.items).contains { $0.path == "Private/Secret" })
  }

  @Test func encodesAndDecodesJSON() throws {
    let store = try Self.makeStore(nodes: [("Home", "Home")])
    let response = store.navContentResponse(
      viewer: NavViewer(isAuthenticated: true, email: "user@example.com")
    )
    let data = try JSONEncoder().encode(response)
    let decoded = try JSONDecoder().decode(NavContentResponse.self, from: data)
    #expect(decoded == response)
  }

  private static func makeStore(
    nodes: [(path: String, title: String)],
    indexPath: String = "Home",
    privateDirectories: Set<String> = []
  ) throws -> ContentStore {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-content-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for node in nodes {
      try writeNode(in: root, path: node.path, title: node.title)
    }
    return try ContentStore(
      contentDirectory: root,
      indexPath: indexPath,
      privateDirectories: privateDirectories
    )
  }

  private static func writeNode(in root: URL, path: String, title: String) throws {
    let wasmURL = root.appendingPathComponent("\(path).wasm")
    try FileManager.default.createDirectory(
      at: wasmURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try wasmBytes.write(to: wasmURL)
    let metaURL = root.appendingPathComponent("\(path).meta.json")
    try JSONSerialization.data(withJSONObject: ["title": title]).write(to: metaURL)
  }

  private static let wasmBytes = Data([0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00])
}
