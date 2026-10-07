import Observation
import SharedKernel

public enum GuardedChatsError: Error, Equatable {
  /// Chats in this messenger can't be guarded in this edition or without a license.
  case messengerUnavailable(Messenger)
}

/// Use cases for managing guarded chats. State changes only after a successful save.
/// Observable, so UIs update when the list changes.
///
/// Every messenger the app supports can be guarded in any number of chats. Which messengers
/// are supported depends on the edition (the open-source core guards WhatsApp; Welp Pro adds
/// more), so chats of an unavailable messenger stay in the list but are not guarded.
@MainActor
@Observable
public final class GuardedChatsService {
  @ObservationIgnored private let repository: any GuardedChatRepository
  @ObservationIgnored private let availability: @MainActor (Messenger) -> Bool
  private var list = GuardedChatList.empty

  public init(
    repository: any GuardedChatRepository,
    isAvailable availability: @escaping @MainActor (Messenger) -> Bool = { _ in true }
  ) {
    self.repository = repository
    self.availability = availability
  }

  public func load() throws {
    list = try repository.load()
  }

  /// Every saved chat, including paused ones and those of unavailable messengers.
  public var chats: [GuardedChat] { list.sorted }
  /// The chats actually guarded right now: not paused, in an available messenger.
  public var activeChats: [GuardedChat] {
    list.sorted.filter { !$0.isPaused && availability($0.id.messenger) }
  }
  public var hasAny: Bool { !activeChats.isEmpty }

  /// Whether chats in `messenger` can be guarded right now.
  public func isAvailable(_ messenger: Messenger) -> Bool {
    availability(messenger)
  }

  /// The chat's mode, or `nil` if it isn't guarded right now (not in the list, paused, or its
  /// messenger is unavailable).
  public func mode(for chat: ChatID) -> ProtectionMode? {
    guard availability(chat.messenger), !list.isPaused(chat) else { return nil }
    return list.mode(for: chat)
  }

  /// Whether `chat` is in the list but paused.
  public func isPaused(_ chat: ChatID) -> Bool {
    list.isPaused(chat)
  }

  public func isGuarded(_ chat: ChatID) -> Bool {
    mode(for: chat) != nil
  }

  public func hasAnyGuarded(in messenger: Messenger) -> Bool {
    availability(messenger) && list.containsActive(in: messenger)
  }

  /// Guards `chat` with `mode`; for a chat already in the list, changes its mode and resumes it.
  public func protect(_ chat: ChatID, mode: ProtectionMode) throws {
    guard availability(chat.messenger) else {
      throw GuardedChatsError.messengerUnavailable(chat.messenger)
    }
    try commit(list.setting(chat, to: mode))
  }

  /// Changes the mode of a chat in the list without resuming a paused one.
  public func setMode(_ mode: ProtectionMode, for chat: ChatID) throws {
    try commit(list.changingMode(of: chat, to: mode))
  }

  /// Pauses or resumes a chat in the list. Resuming needs its messenger to be available.
  public func setPaused(_ isPaused: Bool, for chat: ChatID) throws {
    if !isPaused, !availability(chat.messenger) {
      throw GuardedChatsError.messengerUnavailable(chat.messenger)
    }
    try commit(list.settingPaused(isPaused, for: chat))
  }

  public func unguard(_ chat: ChatID) throws {
    try commit(list.removing(chat))
  }

  /// Unguards `chat` if it is guarded; resumes it with its own mode if it is paused; otherwise
  /// guards it with `mode`. Returns whether it is guarded afterwards.
  @discardableResult
  public func toggle(_ chat: ChatID, mode: ProtectionMode) throws -> Bool {
    if isGuarded(chat) {
      try unguard(chat)
      return false
    }
    if list.isPaused(chat) {
      try setPaused(false, for: chat)
    } else {
      try protect(chat, mode: mode)
    }
    return true
  }

  private func commit(_ next: GuardedChatList) throws {
    guard next != list else { return }
    try repository.save(next)
    list = next
  }
}
