import SwiftUI

#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Settings tab — connection status, server config, and device key management.
struct ShapeTreeSettingsView: View {
  @Bindable var viewModel: ShapeTreeViewModel
  @State private var draftURL: String
  @State private var draftLabel: String
  @State private var regenerateConfirmation = false
  @State private var copyFeedback: String?
  @State private var isCheckingNow = false

  init(viewModel: ShapeTreeViewModel) {
    self.viewModel = viewModel
    self._draftURL = State(initialValue: viewModel.serverURL)
    self._draftLabel = State(initialValue: viewModel.keyStore.deviceLabel)
  }

  var body: some View {
    Form {
      serverSection
      publicKeySection
      connectionStatusSection
    }
    .formStyle(.grouped)
    .alert("Regenerate device key?", isPresented: $regenerateConfirmation) {
      Button("Regenerate", role: .destructive) { regenerateNow() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Existing tokens stop verifying as soon as the server's authorized_keys/<old-kid>.jwk is removed. You'll need to enroll the new public key on the server."
      )
    }
  }

  // MARK: - Connection status

  private var statusColor: Color {
    switch viewModel.connectionState {
    case .online: return .green
    case .unauthorized: return .orange
    case .offline: return .secondary
    }
  }

  private var statusTitle: String {
    switch viewModel.connectionState {
    case .online: return "Connected"
    case .unauthorized: return "Unauthorized"
    case .offline: return "Offline"
    }
  }

  private var statusDescription: String {
    switch viewModel.connectionState {
    case .online:
      return "Server is reachable and this device's key is authorized."
    case .unauthorized:
      return
        "Server is reachable but this device's key isn't enrolled. Copy the public JWK below and save it as authorized_keys/<kid>.jwk on the server."
    case .offline:
      return
        "Server is not responding within 1 second. Check that ShapeTree is running at the URL below and that the device is on the same network."
    }
  }

  private var connectionStatusSection: some View {
    Section("Connection") {
      HStack(alignment: .top, spacing: 12) {
        Circle()
          .frame(width: 10, height: 10)
          .foregroundStyle(statusColor)
          .padding(.top, 3)
        VStack(alignment: .leading, spacing: 4) {
          Text(statusTitle)
            .font(.subheadline.weight(.semibold))
          Text(statusDescription)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.vertical, 4)

      Button {
        isCheckingNow = true
        viewModel.connectionMonitor.start()
        Task {
          try? await Task.sleep(for: .seconds(1))
          isCheckingNow = false
        }
      } label: {
        HStack(spacing: 6) {
          if isCheckingNow {
            ProgressView()
              .scaleEffect(0.7)
              .frame(width: 12, height: 12)
          }
          Text("Check now")
        }
      }
      .disabled(isCheckingNow)
    }
  }

  // MARK: - Server config

  private var serverSection: some View {
    Section {
      TextField("http://localhost:8082", text: $draftURL)
        .textContentType(.URL)
        #if os(iOS)
      .textInputAutocapitalization(.never)
      .keyboardType(.URL)
        #endif
        .onSubmit { applyURL() }

      TextField("Device label", text: $draftLabel)
        #if os(iOS)
      .textInputAutocapitalization(.never)
        #endif
        .onSubmit { applyLabel() }
    } header: {
      Text("Server")
    } footer: {
      Text(
        "Press Return to apply. Use http://127.0.0.1:PORT on this Mac or Simulator; use your Mac's LAN IP on a physical iPhone (same Wi-Fi)."
      )
    }
  }

  // MARK: - Device public key

  @ViewBuilder
  private var publicKeySection: some View {
    Section {
      if let kid = viewModel.currentKid() {
        VStack(alignment: .leading, spacing: 4) {
          Text("kid")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(kid)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
      }

      if let json = viewModel.currentPublicJWKJSON() {
        VStack(alignment: .leading, spacing: 4) {
          Text("public JWK")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          ScrollView(.horizontal, showsIndicators: false) {
            Text(json)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .padding(.vertical, 2)
          }
          .frame(maxHeight: 160)
        }
        .padding(.vertical, 2)

        Button {
          copyToPasteboard(json)
          copyFeedback = "Copied — drop into authorized_keys/<kid>.jwk on the server."
        } label: {
          Label("Copy public JWK", systemImage: "doc.on.doc")
        }
      }

      Button(role: .destructive) {
        regenerateConfirmation = true
      } label: {
        Label("Regenerate device key", systemImage: "arrow.clockwise.circle")
      }

      if let copyFeedback {
        Text(copyFeedback)
          .font(.footnote)
          .foregroundStyle(.green)
      }
    } header: {
      Text("Device public key")
    } footer: {
      Text(
        "Each request is signed with this device's Secure Enclave P-256 key. Enroll by saving the JWK above on the server as authorized_keys/<kid>.jwk."
      )
    }
  }

  // MARK: - Actions

  private func applyURL() {
    let url = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !url.isEmpty, url != viewModel.serverURL else { return }
    viewModel.serverURL = url
    Task { await viewModel.refreshJournalSubjects() }
  }

  private func applyLabel() {
    let label = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    guard label != viewModel.keyStore.deviceLabel else { return }
    viewModel.keyStore.deviceLabel = label
  }

  private func regenerateNow() {
    do {
      try viewModel.regenerateDeviceKey()
      copyFeedback = "New keypair generated — re-enroll the new public JWK before this device can call the server."
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
