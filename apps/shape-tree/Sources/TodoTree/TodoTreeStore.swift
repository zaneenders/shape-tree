import SystemPackage
import _NIOFileSystem

/// TodoTree persistence backed by the local file system via ``FileSystem``.
public struct TodoTreeStore: Sendable {
  public let layout: TodoTreeLayout
  public let fileSystem: FileSystem

  public init(layout: TodoTreeLayout, fileSystem: FileSystem = .shared) {
    self.layout = layout
    self.fileSystem = fileSystem
  }

  /// Ensures ``TodoTreeLayout/dataDirectory`` exists.
  public func bootstrapIfNeeded() async throws {
    try await fileSystem.createDirectory(
      at: layout.dataDirectory,
      withIntermediateDirectories: true,
      permissions: nil
    )
  }
}
