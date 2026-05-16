import OSLog
import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

  private let logger = Logger(subsystem: "org.shapetree.shapetree-client", category: "lifecycle")

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    logger.info("AppDelegate initialized")
    return true
  }
}
