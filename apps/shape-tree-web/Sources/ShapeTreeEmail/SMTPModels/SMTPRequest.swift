enum SMTPRequest: Sendable {
  case sayHello(serverName: String)
  case startTLS
  case beginAuthentication
  case authUser(String)
  case authPassword(String)
  case mailFrom(String)
  case recipient(String)
  case data
  case transferData(OutgoingEmail)
  case quit
}
