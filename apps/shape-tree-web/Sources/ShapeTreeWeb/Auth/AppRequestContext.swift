import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore

struct AppRequestContext: AuthRequestContext, SessionRequestContext, RemoteAddressRequestContext {
  var coreContext: CoreRequestContextStorage
  var identity: User?
  let sessions: SessionContext<UUID>
  var remoteAddress: SocketAddress?

  init(source: Source) {
    self.coreContext = .init(source: source)
    self.identity = nil
    self.sessions = .init()
    self.remoteAddress = source.channel.remoteAddress
  }
}
