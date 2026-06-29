public struct OutgoingEmail: Sendable {
  public var senderName: String?
  public var senderEmail: String
  public var recipientName: String?
  public var recipientEmail: String
  public var subject: String
  public var body: String

  public init(
    senderName: String? = nil,
    senderEmail: String,
    recipientName: String? = nil,
    recipientEmail: String,
    subject: String,
    body: String
  ) {
    self.senderName = senderName
    self.senderEmail = senderEmail
    self.recipientName = recipientName
    self.recipientEmail = recipientEmail
    self.subject = subject
    self.body = body
  }
}
