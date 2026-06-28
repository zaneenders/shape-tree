import NIOCore
import NIOExtras
import NIOPosix
import NIOSSL

public enum SMTPClient {
  /// Sends one email over SMTP using STARTTLS or implicit TLS.
  public static func send(
    email: OutgoingEmail,
    settings: SMTPConnectionSettings
  ) async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    do {
      let promise = group.next().makePromise(of: Void.self)
      let bootstrap = ClientBootstrap(group: group)
        .channelInitializer { channel in
          channel.eventLoop.makeCompletedFuture {
            switch settings.tlsMode {
            case .implicitTLS:
              // TLS wraps the socket from the first byte, so the handler must
              // be in the pipeline before any SMTP traffic (channelInitializer).
              let sslContext = try NIOSSLContext(configuration: TLSConfiguration.makeClientConfiguration())
              try channel.pipeline.syncOperations.addHandler(
                NIOSSLClientHandler(context: sslContext, serverHostname: settings.host),
                position: .first)
            case .startTLS: ()
            // The EHLO + STARTTLS handshake happens in plaintext first;
            // the handler is added later in SendEmailHandler.channelRead
            // at the .okForStartTLS case, after the server says "220 ready".
            case .plain: ()
            // No TLS at all — local mail catchers (Mailpit). See
            // validateTLSConfigured(for:) for the boot-time no-op guard.
            }

            try channel.pipeline.syncOperations.addHandlers([
              ByteToMessageHandler(LineBasedFrameDecoder()),
              SMTPResponseDecoder(),
              MessageToByteHandler(SMTPRequestEncoder()),
              SendEmailHandler(
                configuration: settings,
                email: email,
                allDonePromise: promise
              ),
            ])
          }
        }

      let connection = bootstrap.connect(host: settings.host, port: settings.port)
      connection.cascadeFailure(to: promise)

      try await promise.futureResult.get()
    } catch {
      try await group.shutdownGracefully()
      throw error
    }
    try await group.shutdownGracefully()
  }
}
