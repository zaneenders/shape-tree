import AppKit
import SwiftUI
import UserNotifications

@main
struct ShapeTreeApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var viewModel = ShapeTreeViewModel()

  var body: some Scene {
    WindowGroup {
      ShapeTreeChatView(viewModel: viewModel)
        .task {
          await configurePushRegistration(viewModel: viewModel)
        }
    }
    .windowStyle(.automatic)
    .windowResizability(.contentSize)
    .defaultSize(width: 700, height: 500)
  }

  /// Same sequence as Scribe macOS: handlers → authorization → `registerForRemoteNotifications`.
  @MainActor
  private func configurePushRegistration(viewModel: ShapeTreeViewModel) async {
    appDelegate.deviceTokenHandler = { token in
      Task { @MainActor in
        await viewModel.sendPushDeviceToken(token)
      }
    }
    appDelegate.deviceTokenErrorHandler = { error in
      Task { @MainActor in
        viewModel.pushNotificationError =
          "Failed to register for remote notifications: \(error.localizedDescription)"
      }
    }

    let center = UNUserNotificationCenter.current()
    let options: UNAuthorizationOptions = [.alert, .sound]

    do {
      let granted = try await center.requestAuthorization(options: options)
      if granted {
        NSApplication.shared.registerForRemoteNotifications()
      }
    } catch {
      viewModel.pushNotificationError =
        "Failed to request push notification authorization: \(error.localizedDescription)"
    }
  }
}
