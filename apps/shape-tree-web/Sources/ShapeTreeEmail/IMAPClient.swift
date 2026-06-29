import Logging
import NIOCore
import NIOIMAP
import NIOPosix
import NIOSSL

private let imapLogger = Logger(label: "ShapeTreeEmail.IMAP")

enum IMAPClient {
  private static let headerFields = ["FROM", "SUBJECT", "DATE"]
  private static let fetchAttributes: [FetchAttribute] = [
    .bodySection(peek: true, .headerFields(headerFields), nil),
    .bodySection(peek: true, .text, nil),
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
    imapLogger.info(
      "Connecting to IMAP",
      metadata: [
        "host": "\(settings.host)",
        "port": "\(settings.port)",
        "username": "\(settings.username)",
        "mailbox": "\(mailbox)",
      ])
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
      command: .login(username: settings.username, password: settings.password),
      settings: settings
    )

    let selectResult = try await runChecked(
      on: channel,
      command: .select(mailboxName(mailbox)),
      settings: settings
    )

    let messageCount = messageCount(from: selectResult)
    let searchResult = try await runChecked(
      on: channel,
      command: .uidSearch(key: .all, returnOptions: []),
      settings: settings
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
        command: .fetch(.set(sequenceSet), fetchAttributes, []),
        settings: settings
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
      command: .uidFetch(.set(uidSet), fetchAttributes, []),
      settings: settings
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
    command: Command,
    settings: IMAPConnectionSettings
  ) async throws -> NIMAPCommandResult {
    let result = try await run(on: channel, command: command)
    switch result.tagged.state {
    case .ok:
      return result
    case .no(let text), .bad(let text):
      let reason = text.text
      imapLogger.warning(
        "IMAP command rejected",
        metadata: [
          "host": "\(settings.host)",
          "port": "\(settings.port)",
          "username": "\(settings.username)",
          "reason": "\(reason)",
        ])
      throw IMAPClientError.serverRejected(reason, host: settings.host, port: settings.port)
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
    var bodyText: String?
  }

  var messages: [IncomingEmail] = []
  private var current: PartialMessage?
  private var streamingBuffer: ByteBuffer?
  private var streamingIsBody = false

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

    case .streamingBegin(let kind, _):
      self.streamingBuffer = ByteBuffer()
      self.streamingIsBody = isBodyStream(kind)

    case .streamingBytes(var bytes):
      self.streamingBuffer?.writeBuffer(&bytes)

    case .streamingEnd:
      if var buffer = self.streamingBuffer {
        let text = buffer.readString(length: buffer.readableBytes) ?? ""
        if self.streamingIsBody {
          self.current?.bodyText = text
        } else {
          self.current?.headerText = text
        }
      }
      self.streamingBuffer = nil
      self.streamingIsBody = false

    case .finish:
      self.finalizeCurrent()
    }
  }

  private func isBodyStream(_ kind: StreamingKind) -> Bool {
    switch kind {
    case .body(let section, _):
      return section.kind == .text
    case .rfc822Text:
      return true
    default:
      return false
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
        date: headers["date"] ?? "",
        body: current.bodyText
      )
    )
    self.current = nil
    self.streamingBuffer = nil
    self.streamingIsBody = false
  }
}
