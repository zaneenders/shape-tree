import CryptoKit
import SwiftUI

/// Policy for ShapeTree device keys: persisted only via ``ShapeTreeKeyStore``.
public enum ShapeTreeSecureEnclaveRequirement {

  /// `false` when the platform exposes no usable Secure Enclave (Simulator, some older Mac hardware).
  public static var isSatisfied: Bool {
    SecureEnclave.isAvailable
  }
}

/// Full UI when Secure Enclave is available.
public struct ShapeTreeAppRootView: View {

  @State private var viewModel = ShapeTreeViewModel(serverURL: ShapeTreeViewModel.serverURL)

  public init() {}

  public var body: some View {
    ShapeTreeChatView(viewModel: viewModel)
  }
}

/// Root that blocks the shell when ``ShapeTreeSecureEnclaveRequirement/isSatisfied`` is false.
public struct ShapeTreeGatedLaunchView: View {

  public init() {}

  public var body: some View {
    Group {
      if ShapeTreeSecureEnclaveRequirement.isSatisfied {
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
