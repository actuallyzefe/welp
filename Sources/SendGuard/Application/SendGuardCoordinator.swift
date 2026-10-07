import Foundation
import SharedKernel

/// Holds back send gestures to guarded chats until the user lets them through.
///
/// `handle(_:)` runs inside a system event tap and must return immediately; prompts and
/// countdowns therefore run asynchronously and the send is replayed afterwards.
@MainActor
public final class SendGuardCoordinator {
  public enum Verdict: Sendable, Equatable {
    case pass
    case swallow
  }

  public typealias Scheduler = @MainActor (@escaping @MainActor () -> Void) -> Void

  private let policy: SendGuardPolicy
  private let memory: ApprovalMemory
  private let screen: any SendTargetScreen
  private let prompt: any ConfirmationPrompt
  private let feedback: any SendFeedback
  private let logger: any AppLogger
  private let clock: @MainActor () -> Date
  private let schedule: Scheduler
  private var isAwaitingDecision = false
  /// The send the "Undo" countdown is holding, while it runs.
  private var heldForUndo: SendAttempt?

  public init(
    policy: SendGuardPolicy,
    memory: ApprovalMemory,
    screen: any SendTargetScreen,
    prompt: any ConfirmationPrompt,
    feedback: any SendFeedback,
    logger: any AppLogger,
    clock: @escaping @MainActor () -> Date = { Date() },
    schedule: @escaping Scheduler = { work in Task { @MainActor in work() } }
  ) {
    self.policy = policy
    self.memory = memory
    self.screen = screen
    self.prompt = prompt
    self.feedback = feedback
    self.logger = logger
    self.clock = clock
    self.schedule = schedule
  }

  public func handle(_ gesture: SendGesture) -> Verdict {
    guard let target = screen.sendTarget(for: gesture) else { return .pass }
    // Sending the held message again (Return or the send button) skips the rest of the wait.
    if let held = heldForUndo, held.isRepeated(by: target.context) {
      feedback.finishUndo(.send)
      return .swallow
    }
    let now = clock()

    switch policy.evaluate(target.context, at: now) {
    case .allow:
      return .pass

    case .allowApproved(let chat):
      memory.recordActivity(in: chat, at: now)
      return .pass

    case .confirm(let attempt, let remember):
      return hold { [self] in
        let approved = prompt.confirm(attempt)
        target.restoreFocus()
        logger.info(approved ? "Send approved" : "Send cancelled")
        if approved {
          if remember, let chat = attempt.chat { memory.recordApproval(of: chat, at: clock()) }
          replay(target, of: attempt)
        }
        isAwaitingDecision = false
      }

    case .delay(let attempt, let seconds):
      return hold { [self] in
        heldForUndo = attempt
        feedback.offerUndo(for: attempt, seconds: seconds) { [self] outcome in
          heldForUndo = nil
          logger.info(outcome == .send ? "Undo window passed" : "Send undone")
          if outcome == .send { replay(target, of: attempt) }
          isAwaitingDecision = false
        }
      }
    }
  }

  /// Escape while an "Undo" countdown runs stops the held message, like the Undo button.
  /// Otherwise Escape is none of our business.
  public func handleEscape() -> Verdict {
    guard heldForUndo != nil else { return .pass }
    feedback.finishUndo(.undo)
    return .swallow
  }

  /// Swallows the gesture and runs `decide` later. While a decision is pending, further
  /// sends are swallowed too; they are never let through unchecked.
  private func hold(_ decide: @escaping @MainActor () -> Void) -> Verdict {
    guard !isAwaitingDecision else { return .swallow }
    isAwaitingDecision = true
    schedule(decide)
    return .swallow
  }

  private func replay(_ target: SendTarget, of attempt: SendAttempt) {
    switch target.replay() {
    case .sent:
      break
    case .targetChanged:
      logger.warning("Held send dropped: chat or text changed")
      var returnAndSend: (@MainActor () -> Void)?
      if let reopen = target.reopenChat {
        returnAndSend = { [self] in self.returnAndSend(target, of: attempt, reopen: reopen) }
      }
      feedback.notify(.targetChanged(attempt), returnAndSend: returnAndSend)
    case .failed:
      logger.error("Held send could not be replayed")
      feedback.notify(.sendFailed, returnAndSend: nil)
    }
  }

  /// The user asked to send after all: open the chat again, then replay with the usual
  /// checks, so only the unchanged message can go out, and only to its own chat.
  private func returnAndSend(
    _ target: SendTarget, of attempt: SendAttempt, reopen: SendTarget.ReopenChat
  ) {
    reopen { [self] isOpen in
      guard isOpen else {
        logger.warning("Could not reopen the chat of a held send")
        feedback.notify(.sendFailed, returnAndSend: nil)
        return
      }
      replay(target, of: attempt)
    }
  }
}
