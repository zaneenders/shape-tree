import Foundation
import System

public enum ContentStoreError: Error, CustomStringConvertible, Sendable {
  case directoryNotFound(URL)
  case unreadableFile(URL, underlying: Error)

  public var description: String {
    switch self {
    case .directoryNotFound(let url):
      "Content directory does not exist: \(url.path)"
    case .unreadableFile(let url, let underlying):
      "Could not read \(url.path): \(underlying)"
    }
  }
}

public struct ContentStore: Sendable {
  public let contentRoot: URL
  private let nodesByPath: [String: ContentNode]
  public let indexPath: String
  public let nodes: [ContentNode]
  private let configuredSiteTitle: String?
  private let privateDirectories: Set<String>

  public init(
    contentDirectory: URL,
    indexPath: String,
    siteTitle: String? = nil,
    privateDirectories: Set<String> = []
  ) throws {
    guard FileManager.default.fileExists(atPath: contentDirectory.path) else {
      throw ContentStoreError.directoryNotFound(contentDirectory)
    }

    self.contentRoot = contentDirectory.standardizedFileURL
    self.indexPath = indexPath
    self.configuredSiteTitle = siteTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    self.privateDirectories = privateDirectories
    let loaded = try Self.loadNodes(
      from: contentDirectory,
      indexPath: indexPath,
      privateDirectories: privateDirectories
    )
    self.nodes = loaded.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    self.nodesByPath = Dictionary(uniqueKeysWithValues: loaded.map { ($0.path, $0) })
  }

  public var siteTitle: String {
    if let configuredSiteTitle { return configuredSiteTitle }
    return homeNode?.title ?? "ShapeTree Web"
  }

  public var homeNode: ContentNode? {
    nodesByPath[indexPath] ?? nodes.first { $0.isHome }
  }

  public func node(path rawPath: String) -> ContentNode? {
    for candidate in Self.pathCandidates(for: rawPath) {
      if let node = nodesByPath[candidate] {
        return node
      }
    }
    return nil
  }

  public func canView(path: String, isAuthenticated: Bool) -> Bool {
    guard let node = node(path: path) else { return false }
    return !node.isPrivate || isAuthenticated
  }

  public func canViewFile(relativePath: String, isAuthenticated: Bool) -> Bool {
    let path = FilePath(relativePath)
    guard !path.isEmpty,
      !path.components.contains(where: { $0.kind == .parentDirectory })
    else { return false }
    let directory = path.removingLastComponent()
    guard !directory.isEmpty else { return true }
    for privateDir in privateDirectories {
      if directory.components.starts(with: FilePath(privateDir).components) {
        return isAuthenticated
      }
    }
    return true
  }

  public var publishedNodes: [ContentNode] {
    nodes.filter { !$0.isHome && !$0.isPrivate }
  }

  public func nodeGroups(includingPrivate: Bool) -> [ContentNodeGroup] {
    let visible = nodes.filter { node in
      guard !node.isHome else { return false }
      if node.isPrivate { return includingPrivate }
      return true
    }
    return Self.groupNodes(visible)
  }

  public func resolveFile(relativePath: String) -> URL? {
    guard !relativePath.isEmpty, !relativePath.contains("..") else { return nil }
    let url = contentRoot.appendingPathComponent(relativePath).standardizedFileURL
    let rootPath = contentRoot.standardizedFileURL.path
    guard url.path == rootPath || url.path.hasPrefix(rootPath + "/") else { return nil }
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return url
  }

  public func wasmURL(forPath path: String) -> URL? {
    resolveFile(relativePath: "\(path).wasm")
  }

  public static func humanizedName(_ value: String) -> String {
    value
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  private static func loadNodes(
    from root: URL,
    indexPath: String,
    privateDirectories: Set<String>
  ) throws -> [ContentNode] {
    let fileManager = FileManager.default
    guard
      let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    var nodes: [ContentNode] = []
    for case let fileURL as URL in enumerator {
      guard fileURL.pathExtension.lowercased() == "wasm" else { continue }
      let relativePath = fileURL.path(from: root)
      let path = (relativePath as NSString).deletingPathExtension
      guard !path.isEmpty, !path.contains("..") else { continue }

      let metaURL = fileURL.deletingPathExtension().appendingPathExtension("meta.json")
      let title = try title(forWasmAt: fileURL, metaURL: metaURL, path: path)
      let directory = (path as NSString).deletingLastPathComponent
      let isPrivate = !directory.isEmpty && privateDirectories.contains(directory)
      nodes.append(
        ContentNode(
          path: path,
          title: title,
          isPrivate: isPrivate,
          isHome: path == indexPath
        )
      )
    }
    return nodes
  }

  private static func title(forWasmAt wasmURL: URL, metaURL: URL, path: String) throws -> String {
    if FileManager.default.fileExists(atPath: metaURL.path) {
      do {
        let data = try Data(contentsOf: metaURL)
        let meta = try JSONDecoder().decode(ContentMeta.self, from: data)
        if let title = meta.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
          return title
        }
      } catch {
        throw ContentStoreError.unreadableFile(metaURL, underlying: error)
      }
    }
    return humanizedName((path as NSString).lastPathComponent)
  }

  private static func groupNodes(_ nodes: [ContentNode]) -> [ContentNodeGroup] {
    var grouped: [String?: [ContentNode]] = [:]
    for node in nodes {
      grouped[node.contentDirectory, default: []].append(node)
    }

    let sortedKeys = grouped.keys.sorted { lhs, rhs in
      switch (lhs, rhs) {
      case (nil, nil): return false
      case (nil, _): return true
      case (_, nil): return false
      case (let lhs?, let rhs?):
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
      }
    }

    return sortedKeys.map { directory in
      ContentNodeGroup(
        directory: directory,
        nodes: (grouped[directory] ?? []).sorted {
          $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
      )
    }
  }

  static func pathCandidates(for rawPath: String) -> [String] {
    var candidates: [String] = []
    if let decoded = rawPath.removingPercentEncoding, decoded != rawPath {
      candidates.append(decoded)
    }
    candidates.append(rawPath)
    if rawPath.contains("+") {
      candidates.append(rawPath.replacingOccurrences(of: "+", with: " "))
    }
    var seen = Set<String>()
    return candidates.filter { seen.insert($0).inserted }
  }
}

extension URL {
  fileprivate func path(from root: URL) -> String {
    let rootPath = root.standardizedFileURL.path + "/"
    let fullPath = standardizedFileURL.path
    if fullPath.hasPrefix(rootPath) {
      return String(fullPath.dropFirst(rootPath.count))
    }
    return lastPathComponent
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
