import NIOCore
import NIOIMAP
import NIOPosix
import NIOSSL

enum IMAPClient {
  private static let headerFields = ["FROM", "SUBJECT", "DATE"]
  private static let fetchAttributes: [FetchAttribute] = [
    .bodySection(peek: true, .headerFields(headerFields), nil)
  ]

  /// Fetches the most recent messages from a mailbox (default `INBOX`).
  static func fetchRecent(
    settings: IMAPConnectionSettings,
    mailbox: String = "INBOX",
    limit: Int = 10
  ) async throws -> [IncomingEmail] {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    do {
      let result = try await fetchRecent(
        settings: settings,
        mailbox: mailbox,
        limit: limit,
        group: group
      )
      try await group.shutdownGracefully()
      return result
    } catch {
      try await group.shutdownGracefully()
      throw error
    }
  }

  private static func fetchRecent(
    settings: IMAPConnectionSettings,
    mailbox: String,
    limit: Int,
    group: EventLoopGroup
  ) async throws -> [IncomingEmail] {
    let host = settings.host
    let parserOptions = ResponseParser.Options(bufferLimit: 1_048_576)

    let bootstrap = ClientBootstrap(group: group)
      .channelInitializer { channel in
        channel.eventLoop.makeCompletedFuture {
          let sslContext = try NIOSSLContext(
            configuration: TLSConfiguration.makeClientConfiguration())
          try channel.pipeline.syncOperations.addHandler(
            NIOSSLClientHandler(context: sslContext, serverHostname: host),
            position: .first
          )
          try channel.pipeline.syncOperations.addHandlers([
            IMAPClientHandler(parserOptions: parserOptions),
            NIMAPCommandSession(),
          ])
        }
      }

    let channel = try await bootstrap.connect(host: settings.host, port: settings.port).get()
    defer {
      channel.close(promise: nil)
    }

    try await channel.eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
      do {
        let session = try channel.pipeline.syncOperations.handler(type: NIMAPCommandSession.self)
        return session.whenGreetingReceived(on: channel.eventLoop)
      } catch {
        return channel.eventLoop.makeFailedFuture(error)
      }
    }.get()

    _ = try await runChecked(
      on: channel,
      command: .login(username: settings.username, password: settings.password)
    )

    let selectResult = try await runChecked(
      on: channel,
      command: .select(mailboxName(mailbox))
    )

    let messageCount = messageCount(from: selectResult)
    let searchResult = try await runChecked(
      on: channel,
      command: .uidSearch(key: .all, returnOptions: [])
    )
    var uids = searchUIDs(from: searchResult)

    if uids.isEmpty, let messageCount, messageCount > 0 {
      let start = max(1, Int(messageCount) - max(limit, 1) + 1)
      let range = MessageIdentifierRange<SequenceNumber>(
        SequenceNumber(rawValue: UInt32(start))...SequenceNumber(rawValue: messageCount)
      )
      let sequenceSet = MessageIdentifierSetNonEmpty<SequenceNumber>(range: range)
      let fetchResult = try await runChecked(
        on: channel,
        command: .fetch(.set(sequenceSet), fetchAttributes, [])
      )
      let messages = parseFetchedMessages(from: fetchResult)
      _ = try? await run(on: channel, command: .logout)
      return messages
    }

    if uids.isEmpty {
      _ = try? await run(on: channel, command: .logout)
      return []
    }

    uids.sort()
    let selected = uids.suffix(max(limit, 1))
    guard let uidSet = uidSet(from: selected) else {
      _ = try? await run(on: channel, command: .logout)
      return []
    }

    let fetchResult = try await runChecked(
      on: channel,
      command: .uidFetch(.set(uidSet), fetchAttributes, [])
    )
    let messages = parseFetchedMessages(from: fetchResult)
    _ = try? await run(on: channel, command: .logout)
    return messages
  }

  private static func mailboxName(_ mailbox: String) -> MailboxName {
    if mailbox.uppercased() == "INBOX" {
      return .inbox
    }
    return MailboxName(Array(mailbox.utf8))
  }

  private static func run(
    on channel: Channel,
    command: Command
  ) async throws -> NIMAPCommandResult {
    try await channel.eventLoop.flatSubmit { () -> EventLoopFuture<NIMAPCommandResult> in
      do {
        let session = try channel.pipeline.syncOperations.handler(type: NIMAPCommandSession.self)
        return session.runCommandOnEventLoop(command, channel: channel)
      } catch {
        return channel.eventLoop.makeFailedFuture(error)
      }
    }.get()
  }

  private static func runChecked(
    on channel: Channel,
    command: Command
  ) async throws -> NIMAPCommandResult {
    let result = try await run(on: channel, command: command)
    switch result.tagged.state {
    case .ok:
      return result
    case .no(let text), .bad(let text):
      throw IMAPClientError.serverRejected(text.text)
    }
  }

  private static func messageCount(from result: NIMAPCommandResult) -> UInt32? {
    for response in result.responses {
      guard case .untagged(.mailboxData(.exists(let count))) = response else { continue }
      return UInt32(count)
    }
    return nil
  }

  private static func searchUIDs(from result: NIMAPCommandResult) -> [UInt32] {
    for response in result.responses {
      guard case .untagged(.mailboxData(.search(let ids, _))) = response else { continue }
      return ids.map(\.rawValue)
    }
    return []
  }

  private static func uidSet(from uids: some Collection<UInt32>) -> UIDSetNonEmpty? {
    var set = MessageIdentifierSet<UID>()
    for uid in uids {
      set.insert(UID(rawValue: uid))
    }
    return MessageIdentifierSetNonEmpty(set: set)
  }

  private static func parseFetchedMessages(from result: NIMAPCommandResult) -> [IncomingEmail] {
    var collector = FetchMessageCollector()
    for response in result.responses {
      guard case .fetch(let fetch) = response else { continue }
      collector.handle(fetch)
    }
    return collector.messages
  }
}

private struct FetchMessageCollector {
  private struct PartialMessage {
    var uid: UInt32?
    var sequenceNumber: UInt32?
    var headerText = ""
  }

  var messages: [IncomingEmail] = []
  private var current: PartialMessage?
  private var streamingBuffer: ByteBuffer?

  mutating func handle(_ fetch: FetchResponse) {
    switch fetch {
    case .start(let sequenceNumber):
      self.finalizeCurrent()
      self.current = PartialMessage(sequenceNumber: sequenceNumber.rawValue)

    case .startUID(let uid):
      if self.current == nil {
        self.current = PartialMessage()
      }
      self.current?.uid = uid.rawValue

    case .simpleAttribute(let attribute):
      if case .uid(let uid) = attribute {
        self.current?.uid = uid.rawValue
      }

    case .streamingBegin:
      self.streamingBuffer = ByteBuffer()

    case .streamingBytes(var bytes):
      self.streamingBuffer?.writeBuffer(&bytes)

    case .streamingEnd:
      if var buffer = self.streamingBuffer {
        let headerText = buffer.readString(length: buffer.readableBytes) ?? ""
        self.current?.headerText = headerText
      }
      self.streamingBuffer = nil

    case .finish:
      self.finalizeCurrent()
    }
  }

  private mutating func finalizeCurrent() {
    guard let current else { return }
    let headers = IMAPHeaderParser.parseHeaders(current.headerText)
    self.messages.append(
      IncomingEmail(
        uid: current.uid,
        sequenceNumber: current.sequenceNumber,
        from: headers["from"] ?? "",
        subject: headers["subject"] ?? "",
        date: headers["date"] ?? ""
      )
    )
    self.current = nil
    self.streamingBuffer = nil
  }
}
