import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore

package struct AppRequestContext: AuthRequestContext, SessionRequestContext, RemoteAddressRequestContext {
  package var coreContext: CoreRequestContextStorage
  package var identity: User?
  package let sessions: SessionContext<UUID>
  package var remoteAddress: SocketAddress?

  package init(source: Source) {
    self.coreContext = .init(source: source)
    self.identity = nil
    self.sessions = .init()
    self.remoteAddress = source.channel.remoteAddress
  }
}
