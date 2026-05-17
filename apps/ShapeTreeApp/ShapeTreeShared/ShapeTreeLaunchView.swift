import CryptoKit
import SwiftUI

/// Full UI when Secure Enclave is available.
public struct ShapeTreeAppRootView: View {

  @State private var viewModel = ShapeTreeViewModel(serverURL: ShapeTreeViewModel.serverURL)
  @Environment(\.scenePhase) private var scenePhase

  public init() {}

  public var body: some View {
    ShapeTreeChatView(viewModel: viewModel)
      .onAppear { viewModel.connectionMonitor.start() }
      .onChange(of: scenePhase) { _, newPhase in
        switch newPhase {
        case .active: viewModel.connectionMonitor.start()
        case .background: viewModel.connectionMonitor.stop()
        default: break
        }
      }
  }
}

/// Root that blocks the shell when the platform has no Secure Enclave (Simulator, some older Mac hardware).
public struct ShapeTreeGatedLaunchView: View {

  public init() {}

  public var body: some View {
    Group {
      if SecureEnclave.isAvailable {
        ShapeTreeAppRootView()
      } else {
        SecureEnclaveRequiredScreen()
      }
    }
  }
}

struct SecureEnclaveRequiredScreen: View {
  var body: some View {
    ContentUnavailableView {
      Label("Secure Enclave required", systemImage: "lock.trianglebadge.exclamationmark.fill")
    } description: {
      Text(
        "This app stores its device signing key in the Secure Enclave. Use an iPhone or iPad with a Secure Enclave, or a Mac with Apple silicon or the Apple T2 Security Chip.\n\nThe iOS Simulator is not supported."
      )
      .multilineTextAlignment(.center)
    }
  }
}
