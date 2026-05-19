import SystemPackage

/// On-disk layout for TodoTree data under a workspace root.
public struct TodoTreeLayout: Sendable {
  public static let dotFolderName = ".todo-tree"

  public let root: FilePath

  public init(root: FilePath) {
    self.root = root
  }

  public var dataDirectory: FilePath {
    root.appending(Self.dotFolderName)
  }
}
