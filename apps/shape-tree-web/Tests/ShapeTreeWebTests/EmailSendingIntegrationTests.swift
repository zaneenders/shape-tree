import Foundation
import Testing

@testable import ShapeTreeWeb

/// Live SMTP → IMAP round trip against iCloud (or any provider). Skipped unless explicitly enabled.
///
/// Sends a probe email, then polls IMAP until the message appears in the inbox.
///
/// Required environment variables:
/// - `SMTP_INTEGRATION_TEST=true`
/// - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM`
/// - `SMTP_TEST_TO` — defaults to `SMTP_FROM` (send to self)
/// - IMAP uses the same credentials; optional `IMAP_HOST`, `IMAP_PORT`, `IMAP_MAILBOX`
///
/// ```console
/// swift test --filter EmailRoundTripIntegrationTests
/// ```
@Suite
struct EmailRoundTripIntegrationTests {
  @Test(.enabled(if: Self.integrationEnabled()))
  func roundTripsProbeEmailThroughSMTPAndIMAP() async throws {
    let values = SMTPSettings.mergedEnvironment()
    guard let smtpSettings = SMTPSettings.loadFromEnvironment() else {
      Issue.record("SMTP settings missing despite integration gate")
      return
    }
    guard let imapSettings = IMAPSettings.loadFromEnvironment() else {
      Issue.record("IMAP settings missing despite integration gate")
      return
    }

    let recipient = values["SMTP_TEST_TO"].flatMap { $0.isEmpty ? nil : $0 } ?? smtpSettings.fromAddress
    let mailbox = values["IMAP_MAILBOX"] ?? "INBOX"
    let fetchLimit = max(Int(values["IMAP_FETCH_LIMIT"] ?? "") ?? 20, 1)
    let timeoutSeconds = max(Int(values["IMAP_ROUND_TRIP_TIMEOUT_SECONDS"] ?? "") ?? 60, 1)
    let pollSeconds = max(Int(values["IMAP_ROUND_TRIP_POLL_SECONDS"] ?? "") ?? 3, 1)

    let subject = "zane-enders-website SMTP probe \(ISO8601DateFormatter().string(from: Date()))"
    let body = """
      This is an automated SMTP/IMAP round-trip test from zane-enders-website.

      If you received this, outbound mail for zaneenders.com via iCloud SMTP is working.
      """

    let email = smtpSettings.makeTestEmail(to: recipient, subject: subject, body: body)
    try await SMTPClient.send(email: email, settings: smtpSettings.connection)

    let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
    while Date() < deadline {
      let messages = try await IMAPClient.fetchRecent(
        settings: imapSettings.connection,
        mailbox: mailbox,
        limit: fetchLimit
      )

      if messages.contains(where: { $0.subject == subject || $0.subject.contains(subject) }) {
        return
      }

      try await Task.sleep(for: .seconds(pollSeconds))
    }

    Issue.record(
      "Probe email with subject \"\(subject)\" not found in \(mailbox) within \(timeoutSeconds)s"
    )
  }

  private static func integrationEnabled() -> Bool {
    let values = SMTPSettings.mergedEnvironment()
    guard values["SMTP_INTEGRATION_TEST"]?.lowercased() == "true" else {
      return false
    }
    guard SMTPSettings.loadFromEnvironment() != nil, IMAPSettings.loadFromEnvironment() != nil else {
      return false
    }
    let recipient = values["SMTP_TEST_TO"] ?? values["SMTP_FROM"]
    return !(recipient ?? "").isEmpty
  }
}
