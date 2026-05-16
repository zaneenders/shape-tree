import SwiftUI

@main
struct ShapeTreeApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      ShapeTreeGatedLaunchView()
    }
    .windowStyle(.automatic)
    .windowResizability(.contentSize)
    .defaultSize(width: 700, height: 500)
  }
}
