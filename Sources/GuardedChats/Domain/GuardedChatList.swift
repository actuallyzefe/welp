import Foundation
import SharedKernel

/// Immutable collection of guarded chats, each with its protection mode. A chat can be
/// paused: it stays in the list with its mode, but isn't guarded until it is resumed.
public struct GuardedChatList: Equatable, Sendable {
  private static let turkish = Locale(identifier: "tr_TR")

  private struct Settings: Equatable, Sendable {
    var mode: ProtectionMode
    var isPaused: Bool
  }

  private var entries: [ChatID: Settings]

  public static let empty = GuardedChatList([])

  public init(_ chats: some Sequence<GuardedChat>) {
    entries = Dictionary(
      chats.map { ($0.id, Settings(mode: $0.mode, isPaused: $0.isPaused)) },
      uniquingKeysWith: { first, _ in first })
  }

  public var count: Int { entries.count }
  public var isEmpty: Bool { entries.isEmpty }

  /// The chat's mode, whether or not it is paused.
  public func mode(for chat: ChatID) -> ProtectionMode? {
    entries[chat]?.mode
  }

  public func isPaused(_ chat: ChatID) -> Bool {
    entries[chat]?.isPaused ?? false
  }

  public func contains(_ chat: ChatID) -> Bool {
    entries[chat] != nil
  }

  public func contains(anyIn messenger: Messenger) -> Bool {
    entries.keys.contains { $0.messenger == messenger }
  }

  /// Whether any chat in `messenger` is guarded and not paused.
  public func containsActive(in messenger: Messenger) -> Bool {
    entries.contains { $0.key.messenger == messenger && !$0.value.isPaused }
  }

  /// Adds `chat` (active), or changes its mode and resumes it if it is already in the list.
  public func setting(_ chat: ChatID, to mode: ProtectionMode) -> GuardedChatList {
    var copy = self
    copy.entries[chat] = Settings(mode: mode, isPaused: false)
    return copy
  }

  /// Changes the mode of a chat in the list, keeping it paused or active as it is.
  public func changingMode(of chat: ChatID, to mode: ProtectionMode) -> GuardedChatList {
    guard entries[chat] != nil else { return self }
    var copy = self
    copy.entries[chat]?.mode = mode
    return copy
  }

  public func settingPaused(_ isPaused: Bool, for chat: ChatID) -> GuardedChatList {
    guard entries[chat] != nil else { return self }
    var copy = self
    copy.entries[chat]?.isPaused = isPaused
    return copy
  }

  public func removing(_ chat: ChatID) -> GuardedChatList {
    var copy = self
    copy.entries[chat] = nil
    return copy
  }

  /// Ordered by messenger, then workspace, then name (Turkish collation).
  public var sorted: [GuardedChat] {
    entries
      .map { GuardedChat(id: $0.key, mode: $0.value.mode, isPaused: $0.value.isPaused) }
      .sorted { Self.precedes($0.id, $1.id) }
  }

  private static func precedes(_ lhs: ChatID, _ rhs: ChatID) -> Bool {
    let left = [lhs.messenger.displayName, lhs.workspace?.value ?? "", lhs.name.value]
    let right = [rhs.messenger.displayName, rhs.workspace?.value ?? "", rhs.name.value]
    for (a, b) in zip(left, right) where a != b {
      return a.compare(b, options: .caseInsensitive, locale: turkish) == .orderedAscending
    }
    return false
  }
}
