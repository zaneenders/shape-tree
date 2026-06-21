import NIOCore
import NIOIMAP

package struct NIMAPCommandResult: Sendable {
  package var responses: [Response]
  package var tagged: TaggedResponse

  package init(responses: [Response], tagged: TaggedResponse) {
    self.responses = responses
    self.tagged = tagged
  }
}

package final class NIMAPCommandSession: ChannelDuplexHandler {
  package typealias InboundIn = Response
  package typealias OutboundIn = IMAPClientHandler.Message
  package typealias OutboundOut = IMAPClientHandler.Message

  private enum GreetingState {
    case waiting(EventLoopPromise<Void>)
    case received
  }

  private var tagCounter = 0
  private var pendingTag: String?
  private var pendingResponses: [Response] = []
  private var pendingPromise: EventLoopPromise<NIMAPCommandResult>?
  private var greetingState: GreetingState?

  package init() {}

  package func handlerAdded(context: ChannelHandlerContext) {
    if self.greetingState == nil {
      self.greetingState = .waiting(context.eventLoop.makePromise(of: Void.self))
    }
  }

  package func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
    context.write(data, promise: promise)
  }

  package func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    self.handleResponse(self.unwrapInboundIn(data))
  }

  package func errorCaught(context: ChannelHandlerContext, error: Error) {
    self.failGreeting(error)
    self.failPending(error)
    context.close(promise: nil)
  }

  package func channelInactive(context: ChannelHandlerContext) {
    self.failGreeting(ChannelError.eof)
    self.failPending(ChannelError.eof)
  }

  package func whenGreetingReceived(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    eventLoop.preconditionInEventLoop()
    switch self.greetingState {
    case .received:
      return eventLoop.makeSucceededFuture(())
    case .waiting(let promise):
      return promise.futureResult
    case nil:
      let promise = eventLoop.makePromise(of: Void.self)
      self.greetingState = .waiting(promise)
      return promise.futureResult
    }
  }

  package func runCommandOnEventLoop(
    _ command: Command,
    channel: Channel
  ) -> EventLoopFuture<NIMAPCommandResult> {
    channel.eventLoop.preconditionInEventLoop()

    if self.pendingPromise != nil {
      return channel.eventLoop.makeFailedFuture(
        IMAPClientError.protocolError("IMAP command already in flight")
      )
    }

    self.tagCounter += 1
    let tag = String(format: "A%03d", self.tagCounter)
    self.pendingTag = tag
    self.pendingResponses = []

    let promise = channel.eventLoop.makePromise(of: NIMAPCommandResult.self)
    self.pendingPromise = promise

    let tagged = TaggedCommand(tag: tag, command: command)
    let message = IMAPClientHandler.Message.part(.tagged(tagged))

    channel.writeAndFlush(message).cascadeFailure(to: promise)

    return promise.futureResult
  }

  private func handleResponse(_ response: Response) {
    if case .waiting(let promise) = self.greetingState, self.pendingPromise == nil {
      self.greetingState = .received
      promise.succeed(())
      return
    }

    guard self.pendingPromise != nil else {
      return
    }

    switch response {
    case .tagged(let tagged):
      do {
        try IMAPCommandTagMatching.validate(tagged.tag, matches: self.pendingTag)
      } catch {
        self.failPending(error)
        return
      }
      let result = NIMAPCommandResult(responses: self.pendingResponses, tagged: tagged)
      self.pendingResponses = []
      self.pendingTag = nil
      let promise = self.pendingPromise
      self.pendingPromise = nil
      promise?.succeed(result)

    case .fetch, .untagged, .fatal, .authenticationChallenge, .idleStarted:
      self.pendingResponses.append(response)
    }
  }

  private func failGreeting(_ error: Error) {
    guard case .waiting(let promise) = self.greetingState else { return }
    self.greetingState = .received
    promise.fail(error)
  }

  private func failPending(_ error: Error) {
    guard let promise = self.pendingPromise else { return }
    self.pendingPromise = nil
    self.pendingTag = nil
    self.pendingResponses = []
    promise.fail(error)
  }
}
