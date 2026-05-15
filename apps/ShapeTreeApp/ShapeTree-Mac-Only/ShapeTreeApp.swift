import SwiftUI

@main
struct ShapeTreeApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var viewModel = ShapeTreeViewModel(serverURL: ShapeTreeViewModel.serverURL)

  var body: some Scene {
    WindowGroup {
      ShapeTreeChatView(viewModel: viewModel)
    }
    .windowStyle(.automatic)
    .windowResizability(.contentSize)
    .defaultSize(width: 700, height: 500)
  }
}
