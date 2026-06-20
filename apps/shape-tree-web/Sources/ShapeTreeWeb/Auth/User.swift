import Foundation

struct User: Sendable, Codable, Equatable {
  let id: UUID
  let email: String
  let createdAt: Date
}
