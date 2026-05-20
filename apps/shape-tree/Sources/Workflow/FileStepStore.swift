import Foundation
import SystemPackage
import _NIOFileSystem

public final class FileStepStore: Sendable {
  private let root: FilePath

  public init(root: FilePath) async throws {
    self.root = root
    try await FileSystem.shared.createDirectory(
      at: root,
      withIntermediateDirectories: true,
      permissions: FilePermissions(rawValue: 0o755)
    )
  }

  public func load(workflowID: String, stepKey: String) async throws -> Data? {
    let path = stepPath(workflowID: workflowID, stepKey: stepKey)
    do {
      let bytes = try await [UInt8](contentsOf: path, maximumSizeAllowed: .megabytes(1))
      return Data(bytes)
    } catch let e as FileSystemError where e.code == .notFound {
      return nil
    }
  }

  public func save(workflowID: String, stepKey: String, data: Data) async throws {
    try await FileSystem.shared.createDirectory(
      at: root.appending(workflowID),
      withIntermediateDirectories: true,
      permissions: nil
    )
    _ = try await FileSystem.shared.withFileHandle(
      forWritingAt: stepPath(workflowID: workflowID, stepKey: stepKey),
      options: .newFile(replaceExisting: true, permissions: nil)
    ) { handle in
      try await handle.write(contentsOf: data, toAbsoluteOffset: 0)
    }
  }

  private func stepPath(workflowID: String, stepKey: String) -> FilePath {
    root.appending(workflowID).appending("\(stepKey).json")
  }
}
