import AppKit
import OSLog
import SwiftUI

/// Mirrors Scribe's macOS `AppDelegate` for ShapeTree client lifecycle.
final class AppDelegate: NSObject, NSApplicationDelegate {

  private let logger = Logger(subsystem: "org.shapetree.shapetree-client", category: "lifecycle")

  func applicationDidFinishLaunching(_ notification: Notification) {
    logger.info("AppDelegate initialized")
  }
}
