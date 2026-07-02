import Foundation
import SystemPackage

extension FilePath {
  public init<S: StringProtocol>(expandingTildeIn path: S) {
    self.init((String(path) as NSString).expandingTildeInPath)
  }

  public var expandingTildeInPath: FilePath {
    FilePath((string as NSString).expandingTildeInPath)
  }
}
