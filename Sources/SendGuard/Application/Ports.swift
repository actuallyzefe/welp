import CoreGraphics
import Foundation

/// A raw user gesture that may send a message.
public enum SendGesture: Sendable, Equatable {
  /// Return / Enter. `withCommand` is ⌘ or ⌃ held (Slack's "send" shortcut in newline mode).
  /// `targetProcess` is the process that actually receives the key, which is not always
  /// the frontmost app (e.g. Raycast's or Spotlight's panels).
  case returnKey(withCommand: Bool, targetProcess: Int32)
  case click(at: CGPoint)
}

public enum ReplayResult: Sendable, Equatable {
  case sent
  /// The chat or the text changed while the send was held; nothing was sent.
  case targetChanged
  case failed
}

/// A gesture a screen recognised as "send", plus how to finish it later.
@MainActor
public struct SendTarget {
  public let context: SendContext
  /// Performs the held send, but only if the chat and text are still the same.
  public let replay: @MainActor () -> ReplayResult
  /// Gives the messenger keyboard focus back after a modal prompt closes.
  public let restoreFocus: @MainActor () -> Void
  /// Opens the held send's chat again after the user left it, then reports whether that
  /// chat is on screen. `nil` when the messenger offers no reliable way back.
  public let reopenChat: ReopenChat?

  public typealias ReopenChat =
    @MainActor (_ completion: @escaping @MainActor (_ isOpen: Bool) -> Void) -> Void

  public init(
    context: SendContext,
    replay: @escaping @MainActor () -> ReplayResult,
    restoreFocus: @escaping @MainActor () -> Void,
    reopenChat: ReopenChat? = nil
  ) {
    self.context = context
    self.replay = replay
    self.restoreFocus = restoreFocus
    self.reopenChat = reopenChat
  }
}

/// One messenger's UI, as seen from outside.
@MainActor
public protocol SendTargetScreen: AnyObject {
  /// `nil` when the gesture is not a send inside this messenger.
  func sendTarget(for gesture: SendGesture) -> SendTarget?
}

/// Asks the user to approve a send. Returns `true` only on explicit approval.
@MainActor
public protocol ConfirmationPrompt {
  func confirm(_ attempt: SendAttempt) -> Bool
}

/// Something the user should know about a held send that did not go out.
public enum SendNotice: Sendable, Equatable {
  /// The chat or the text changed while the send was held; nothing was sent.
  case targetChanged(SendAttempt)
  /// The held send could not be performed.
  case sendFailed
}

public enum UndoOutcome: Sendable, Equatable {
  case send
  case undo
}

/// Non-blocking feedback: the "Undo" countdown and short notices.
@MainActor
public protocol SendFeedback {
  func offerUndo(
    for attempt: SendAttempt, seconds: TimeInterval,
    completion: @escaping @MainActor (UndoOutcome) -> Void)
  /// Ends the running countdown now: `.send` sends without waiting, `.undo` drops it.
  func finishUndo(_ outcome: UndoOutcome)
  /// `returnAndSend`, when given, is offered as a button: go back to the chat and send.
  func notify(_ notice: SendNotice, returnAndSend: (@MainActor () -> Void)?)
}
