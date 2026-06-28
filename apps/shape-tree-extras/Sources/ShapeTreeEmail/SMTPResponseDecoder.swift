import NIOCore

final class SMTPResponseDecoder: ChannelInboundHandler, Sendable {
  typealias InboundIn = ByteBuffer
  typealias InboundOut = SMTPResponse

  init() {}

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var response = self.unwrapInboundIn(data)

    guard
      let firstFourBytes = response.readString(length: 4),
      let code = Int(firstFourBytes.dropLast())
    else {
      context.fireErrorCaught(SMTPResponseDecoderError.malformedMessage)
      return
    }

    let remainder = response.readString(length: response.readableBytes) ?? ""
    let firstCharacter = firstFourBytes.first!
    let fourthCharacter = firstFourBytes.last!

    switch (firstCharacter, fourthCharacter) {
    case ("2", " "),
      ("3", " "):
      context.fireChannelRead(self.wrapInboundOut(.ok(code, remainder)))
    case (_, "-"):
      ()  // intermediate EHLO line
    default:
      context.fireChannelRead(self.wrapInboundOut(.error(firstFourBytes + remainder)))
    }
  }
}

enum SMTPResponseDecoderError: Error {
  case malformedMessage
}
