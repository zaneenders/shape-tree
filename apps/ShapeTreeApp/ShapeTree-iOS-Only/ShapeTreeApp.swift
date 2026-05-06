import SwiftUI

@main
struct ShapeTreeApp: App {
  @State private var viewModel = ShapeTreeViewModel()

  var body: some Scene {
    WindowGroup {
      ShapeTreeChatView(viewModel: viewModel)
    }
  }
}
