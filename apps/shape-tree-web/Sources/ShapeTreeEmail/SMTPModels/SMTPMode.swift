public enum SMTPTLSMode: Sendable {
  /// Plain SMTP (no TLS, no AUTH) — local dev mail catchers like Mailpit.
  case plain
  /// STARTTLS on a plain connection (iCloud default on port 587).
  case startTLS
  /// TLS from the first byte (port 465).
  case implicitTLS
}
