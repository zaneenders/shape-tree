import SwiftUI

@main
struct ShapeTreeApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      ShapeTreeGatedLaunchView()
    }
  }
}
