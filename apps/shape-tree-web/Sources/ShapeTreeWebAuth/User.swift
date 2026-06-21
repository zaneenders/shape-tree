import Foundation

package struct User: Sendable, Codable, Equatable {
  let id: UUID
  package let email: String
  let createdAt: Date
}
