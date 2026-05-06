import SwiftUI

@main
struct ShapeTreeApp: App {
  @State private var viewModel = ShapeTreeViewModel()

  var body: some Scene {
    WindowGroup {
      ShapeTreeChatView(viewModel: viewModel)
    }
    .windowStyle(.automatic)
    .windowResizability(.contentSize)
    .defaultSize(width: 700, height: 500)
  }
}
