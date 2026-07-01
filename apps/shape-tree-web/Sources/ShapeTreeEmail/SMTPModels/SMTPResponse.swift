enum SMTPResponse: Sendable {
  case ok(Int, String)
  case error(String)
}
