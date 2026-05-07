import OSLog
import SwiftUI
import UIKit
import UserNotifications

/// Mirrors Scribe’s `AppDelegate`: forwards APNs callbacks into SwiftUI-owned handlers.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

  var deviceTokenHandler: ((String) -> Void)?
  var deviceTokenErrorHandler: ((Error) -> Void)?

  private let logger = Logger(subsystem: "org.shapetree.shapetree-client", category: "apns")

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    logger.info("AppDelegate initialized; notification center delegate set")
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    logger.info("Received device token prefix=\(String(tokenString.prefix(20)))...")
    deviceTokenHandler?(tokenString)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    deviceTokenErrorHandler?(error)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    logger.info("Will present notification in foreground id=\(notification.request.identifier)")
    completionHandler([.banner, .sound, .badge])
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
