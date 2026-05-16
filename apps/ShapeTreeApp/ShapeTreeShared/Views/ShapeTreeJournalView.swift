import SwiftUI

struct ShapeTreeJournalView: View {
  @Bindable var viewModel: ShapeTreeViewModel

  var body: some View {
    ZStack {
      ShapeTreeJournalContainerView(journalModel: viewModel)

      if viewModel.isJournalWorking {
        ZStack {
          Color.black.opacity(0.06)
          ProgressView("Working…")
            .padding(.vertical, 28)
            .padding(.horizontal, 40)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
      }
    }
  }
}
