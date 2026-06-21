import Foundation
import Hummingbird
import Logging

struct AuthServices: Sendable {
  let database: any AuthDatabase
  let persist: any PersistDriver
  let settings: AuthSettings
  let smtp: SMTPSettings
  let siteURL: String
  let secureCookies: Bool
  let privateDirectories: Set<String>
}
