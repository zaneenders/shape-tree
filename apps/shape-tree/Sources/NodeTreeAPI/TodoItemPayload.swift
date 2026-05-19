import Foundation

public enum TodoItemStatus: String, Codable, Sendable, Equatable, CaseIterable {
  case open
  case completed
  case archive
}

/// Todo payload stored in each node's `node.json` for `todo-tree` and similar stores.
public struct TodoItemPayload: Codable, Sendable, Equatable {
  public var title: String
  public var status: TodoItemStatus
  public var notes: String?

  public init(title: String, status: TodoItemStatus = .open, notes: String? = nil) {
    self.title = title
    self.status = status
    self.notes = notes
  }

  public enum CodingKeys: String, CodingKey {
    case title
    case status
    case completed
    case notes
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    title = try container.decode(String.self, forKey: .title)
    notes = try container.decodeIfPresent(String.self, forKey: .notes)
    if let status = try container.decodeIfPresent(TodoItemStatus.self, forKey: .status) {
      self.status = status
    } else if let completed = try container.decodeIfPresent(Bool.self, forKey: .completed) {
      self.status = completed ? .completed : .open
    } else {
      self.status = .open
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(title, forKey: .title)
    try container.encode(status, forKey: .status)
    try container.encodeIfPresent(notes, forKey: .notes)
  }
}

extension TodoItemPayload {
  public var isSettled: Bool {
    status == .completed || status == .archive
  }
}
