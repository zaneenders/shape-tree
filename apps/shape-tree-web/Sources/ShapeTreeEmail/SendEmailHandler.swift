import NIOCore
import NIOSSL

private let smtpSSLContext = try! NIOSSLContext(
  configuration: TLSConfiguration.makeClientConfiguration())

final class SendEmailHandler: ChannelInboundHandler {
  typealias InboundIn = SMTPResponse
  typealias OutboundIn = OutgoingEmail
  typealias OutboundOut = SMTPRequest

  private enum Expect {
    case initialMessageFromServer
    case okForOurHello
    case okForStartTLS
    case okForPostTLSHello
    case okForOurAuthBegin
    case okAfterUsername
    case okAfterPassword
    case okAfterMailFrom
    case okAfterRecipient
    case okAfterDataCommand
    case okAfterMailData
    case okAfterQuit
    case nothing
    case error(Error)
  }

  private var currentlyWaitingFor = Expect.initialMessageFromServer {
    didSet {
      if case .error(let error) = self.currentlyWaitingFor {
        self.allDonePromise.fail(error)
      }
    }
  }

  private let email: OutgoingEmail
  private let serverConfiguration: SMTPConnectionSettings
  private let allDonePromise: EventLoopPromise<Void>

  init(
    configuration: SMTPConnectionSettings,
    email: OutgoingEmail,
    allDonePromise: EventLoopPromise<Void>
  ) {
    self.email = email
    self.serverConfiguration = configuration
    self.allDonePromise = allDonePromise
  }

  func channelInactive(context: ChannelHandlerContext) {
    switch self.currentlyWaitingFor {
    case .okAfterQuit, .nothing:
      return
    default:
      self.allDonePromise.fail(ChannelError.eof)
    }
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    self.currentlyWaitingFor = .error(error)
    self.allDonePromise.fail(error)
    context.close(promise: nil)
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let result = self.unwrapInboundIn(data)
    switch result {
    case .error(let message):
      self.allDonePromise.fail(SMTPClientError.serverRejected(message))
      return
    case .ok:
      ()
    }

    switch self.currentlyWaitingFor {
    case .initialMessageFromServer:
      self.send(context: context, command: .sayHello(serverName: self.serverConfiguration.host))
      self.currentlyWaitingFor = .okForOurHello
    case .okForOurHello:
      switch self.serverConfiguration.tlsMode {
      case .plain:
        self.send(context: context, command: .mailFrom(self.email.senderEmail))
        self.currentlyWaitingFor = .okAfterMailFrom
      case .startTLS:
        self.send(context: context, command: .startTLS)
        self.currentlyWaitingFor = .okForStartTLS
      case .implicitTLS:
        self.sendAuthenticationStart(context: context)
      }
    case .okForStartTLS:
      do {
        try context.channel.pipeline.syncOperations.addHandler(
          try NIOSSLClientHandler(
            context: smtpSSLContext,
            serverHostname: self.serverConfiguration.host
          ),
          position: .first
        )
        self.send(context: context, command: .sayHello(serverName: self.serverConfiguration.host))
        self.currentlyWaitingFor = .okForPostTLSHello
      } catch {
        self.currentlyWaitingFor = .error(error)
      }
    case .okForPostTLSHello:
      self.sendAuthenticationStart(context: context)
    case .okForOurAuthBegin:
      self.send(context: context, command: .authUser(self.serverConfiguration.username))
      self.currentlyWaitingFor = .okAfterUsername
    case .okAfterUsername:
      self.send(context: context, command: .authPassword(self.serverConfiguration.password))
      self.currentlyWaitingFor = .okAfterPassword
    case .okAfterPassword:
      self.send(context: context, command: .mailFrom(self.email.senderEmail))
      self.currentlyWaitingFor = .okAfterMailFrom
    case .okAfterMailFrom:
      self.send(context: context, command: .recipient(self.email.recipientEmail))
      self.currentlyWaitingFor = .okAfterRecipient
    case .okAfterRecipient:
      self.send(context: context, command: .data)
      self.currentlyWaitingFor = .okAfterDataCommand
    case .okAfterDataCommand:
      self.send(context: context, command: .transferData(self.email))
      self.currentlyWaitingFor = .okAfterMailData
    case .okAfterMailData:
      self.send(context: context, command: .quit)
      self.currentlyWaitingFor = .okAfterQuit
    case .okAfterQuit:
      self.allDonePromise.succeed(())
      context.close(promise: nil)
      self.currentlyWaitingFor = .nothing
    case .nothing:
      ()
    case .error:
      ()
    }
  }

  private func send(context: ChannelHandlerContext, command: SMTPRequest) {
    context.writeAndFlush(self.wrapOutboundOut(command)).cascadeFailure(to: self.allDonePromise)
  }

  private func sendAuthenticationStart(context: ChannelHandlerContext) {
    switch self.serverConfiguration.tlsMode {
    case .plain:
      return
    case .implicitTLS, .startTLS:
      do {
        _ = try context.channel.pipeline.syncOperations.handler(type: NIOSSLClientHandler.self)
        self.send(context: context, command: .beginAuthentication)
        self.currentlyWaitingFor = .okForOurAuthBegin
      } catch {
        let tlsMode = self.serverConfiguration.tlsMode
        preconditionFailure("TLS handler should be present for \(tlsMode) but \(error)")
      }
    }
  }
}
