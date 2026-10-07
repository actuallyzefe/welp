/// Persistence port for the guarded chat list.
public protocol GuardedChatRepository: Sendable {
  func load() throws -> GuardedChatList
  func save(_ list: GuardedChatList) throws
}
