import SwiftUI

@main
struct ShapeTreeApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var viewModel = ShapeTreeViewModel(serverURL: ShapeTreeViewModel.defaultServerURL)

  var body: some Scene {
    WindowGroup {
      ShapeTreeChatView(viewModel: viewModel)
    }
  }
}
