package enum IMAPCommandTagMatching {
  package static func validate(_ receivedTag: String, matches expectedTag: String?) throws {
    guard receivedTag == expectedTag else {
      throw IMAPClientError.unexpectedResponse(
        "expected tag \(expectedTag ?? "nil"), got \(receivedTag)"
      )
    }
  }
}
