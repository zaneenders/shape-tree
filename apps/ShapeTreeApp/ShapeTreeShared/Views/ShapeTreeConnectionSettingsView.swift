import SwiftUI

#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// "Connection" sheet shown from the chat header. Owns its own draft state so each presentation
/// starts pre-filled with the live values and discards drafts on cancel.
struct ShapeTreeConnectionSettingsView: View {
  @Bindable var viewModel: ShapeTreeViewModel
  @Binding var isPresented: Bool

  @State private var draftURL: String
  @State private var draftLabel: String
  @State private var regenerateConfirmation = false
  @State private var copyFeedback: String?

  init(viewModel: ShapeTreeViewModel, isPresented: Binding<Bool>) {
    self.viewModel = viewModel
    self._isPresented = isPresented
    self._draftURL = State(initialValue: viewModel.serverURL)
    self._draftLabel = State(initialValue: viewModel.keyStore.deviceLabel)
  }

  var body: some View {
    NavigationStack {
      Form {
        serverSection
        deviceLabelSection
        publicKeySection
      }
      .navigationTitle("Connection")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar { doneToolbar }
      .alert("Regenerate device key?", isPresented: $regenerateConfirmation) {
        Button("Regenerate", role: .destructive) { regenerateNow() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "Existing tokens stop verifying as soon as the server's authorized_keys/<old-kid>.jwk is removed. You'll need to enroll the new public key on the server."
        )
      }
    }
    #if os(macOS)
    .frame(minWidth: 480, minHeight: 460)
    #endif
  }

  private var serverSection: some View {
    Section {
      TextField("Server URL", text: $draftURL)
        .textContentType(.URL)
        #if os(iOS)
      .textInputAutocapitalization(.never)
      .keyboardType(.URL)
        #endif
    } header: {
      Text("ShapeTree server")
    } footer: {
      Text(
        "Use http://127.0.0.1:PORT on this Mac or Simulator. On a physical iPhone, use your Mac's LAN IP (same Wi-Fi), not 127.0.0.1."
      )
    }
  }

  private var deviceLabelSection: some View {
    Section {
      TextField("Device label", text: $draftLabel)
        #if os(iOS)
      .textInputAutocapitalization(.never)
        #endif
    } header: {
      Text("Device label")
    } footer: {
      Text(
        "Carried in the JWT `dev` header for log breadcrumbs only. Identity is the public key thumbprint."
      )
    }
  }

  @ViewBuilder
  private var publicKeySection: some View {
    Section {
      if let kid = viewModel.currentKid() {
        VStack(alignment: .leading, spacing: 6) {
          Text("kid")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(kid)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if let json = viewModel.currentPublicJWKJSON() {
        ScrollView(.horizontal) {
          Text(json)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 220)

        Button {
          copyToPasteboard(json)
          copyFeedback = "Copied. Drop into authorized_keys/<kid>.jwk on the server."
        } label: {
          Label("Copy public JWK", systemImage: "doc.on.doc")
        }
        #if os(macOS)
        .buttonStyle(.borderless)
        #endif
      }

      Button(role: .destructive) {
        regenerateConfirmation = true
      } label: {
        Label("Regenerate device key", systemImage: "arrow.clockwise.circle")
      }
      #if os(macOS)
      .buttonStyle(.borderless)
      #endif

      if let copyFeedback {
        Text(copyFeedback)
          .font(.footnote)
          .foregroundStyle(.green)
      }
    } header: {
      Text("Device public key")
    } footer: {
      Text(
        "Each request is signed with this device's Secure Enclave P-256 key. Enroll the device by copying the JWK above and saving it on the server as authorized_keys/<kid>.jwk."
      )
    }
  }

  @ToolbarContentBuilder
  private var doneToolbar: some ToolbarContent {
    ToolbarItem(placement: .confirmationAction) {
      Button("Done") { commitDrafts() }
    }
  }

  private func commitDrafts() {
    let url = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
    let label = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)

    if !url.isEmpty, url != viewModel.serverURL {
      viewModel.serverURL = url
    }
    if label != viewModel.keyStore.deviceLabel {
      viewModel.keyStore.deviceLabel = label
    }
    isPresented = false
    Task {
      await viewModel.refreshJournalSubjects()
    }
  }

  private func regenerateNow() {
    do {
      try viewModel.regenerateDeviceKey()
      copyFeedback =
        "New keypair generated. Re-enroll the new public JWK before this device can call the server."
    } catch {
      copyFeedback = "Failed to regenerate: \(error.localizedDescription)"
    }
  }

  private func copyToPasteboard(_ value: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    #elseif canImport(UIKit)
    UIPasteboard.general.string = value
    #endif
  }
}
