import Foundation
import GuardedChats
import Preferences
import SendGuard
import SharedKernel

/// Adapts the guarded-chats module to the send-guard module's port.
@MainActor
struct GuardedChatsLookup: GuardedChatLookup {
  let service: GuardedChatsService

  func protection(for chat: ChatID) -> ProtectionMode? {
    service.mode(for: chat)
  }

  func hasAnyGuarded(in messenger: Messenger) -> Bool {
    service.hasAnyGuarded(in: messenger)
  }
}

extension Preferences {
  /// The timing the send guard needs, derived from the user's settings.
  var guardBehavior: GuardBehavior {
    GuardBehavior(
      reaskAfterIdle: reasksAfterIdle ? TimeInterval(idleMinutes * 60) : nil,
      undoDelay: TimeInterval(undoSeconds)
    )
  }
}
