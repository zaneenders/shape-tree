import AppKit
import OSLog
import SwiftUI
import UserNotifications

/// Mirrors Scribe’s macOS `AppDelegate`: forwards APNs callbacks into SwiftUI-owned handlers.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

  var deviceTokenHandler: ((String) -> Void)?
  var deviceTokenErrorHandler: ((Error) -> Void)?

  private let logger = Logger(subsystem: "org.shapetree.shapetree-client", category: "apns")

  func applicationDidFinishLaunching(_ notification: Notification) {
    logger.info("AppDelegate initialized; notification center delegate set")
    UNUserNotificationCenter.current().delegate = self
  }

  func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    logger.info("Received device token prefix=\(String(tokenString.prefix(20)))...")
    deviceTokenHandler?(tokenString)
  }

  func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    deviceTokenErrorHandler?(error)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    logger.info("Will present notification in foreground id=\(notification.request.identifier)")
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    logger.info("User tapped notification id=\(response.notification.request.identifier)")
    completionHandler()
  }
}
