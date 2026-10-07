import Foundation
import SharedKernel

/// Read access to the guarded chats, needed synchronously while an input event is held.
@MainActor
public protocol GuardedChatLookup {
  func protection(for chat: ChatID) -> ProtectionMode?
  func hasAnyGuarded(in messenger: Messenger) -> Bool
}

public enum SendDecision: Sendable, Equatable {
  case allow
  /// Allowed because the chat was approved earlier during this visit.
  case allowApproved(ChatID)
  /// Ask first. `remember` keeps the approval for the rest of the visit.
  case confirm(SendAttempt, remember: Bool)
  /// Hold the message with an "Undo" notice, then send it.
  case delay(SendAttempt, seconds: TimeInterval)
}

/// The business rule.
///
/// Fails closed: if the chat cannot be identified, it is treated as guarded (with the
/// strictest mode) as long as anything in that messenger is guarded.
@MainActor
public struct SendGuardPolicy {
  private let lookup: any GuardedChatLookup
  private let memory: ApprovalMemory
  private let behavior: @MainActor () -> GuardBehavior

  public init(
    lookup: any GuardedChatLookup,
    memory: ApprovalMemory,
    behavior: @escaping @MainActor () -> GuardBehavior
  ) {
    self.lookup = lookup
    self.memory = memory
    self.behavior = behavior
  }

  public func evaluate(_ context: SendContext, at now: Date) -> SendDecision {
    guard !context.isEmpty else { return .allow }

    let attempt = SendAttempt(
      messenger: context.messenger, chat: context.chat, text: context.text,
      trigger: context.trigger)

    guard let chat = context.chat else {
      return lookup.hasAnyGuarded(in: context.messenger)
        ? .confirm(attempt, remember: false) : .allow
    }

    switch lookup.protection(for: chat) {
    case nil:
      return .allow
    case .everyMessage:
      return .confirm(attempt, remember: false)
    case .firstMessage:
      let approved = memory.isApproved(chat, at: now, idleLimit: behavior().reaskAfterIdle)
      return approved ? .allowApproved(chat) : .confirm(attempt, remember: true)
    case .undo:
      return .delay(attempt, seconds: behavior().undoDelay)
    }
  }
}
