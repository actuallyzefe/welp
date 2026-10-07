import CoreGraphics
import Foundation
import SendGuard
import SharedKernel

enum TestChats {
  static let customer = ChatID(messenger: .whatsApp, name: ChatName("Acme Müşteri")!)
  static let friend = ChatID(messenger: .whatsApp, name: ChatName("Ali")!)
  static let slackGeneral = ChatID(
    messenger: .slack, workspace: ChatName("Acme"), name: ChatName("general")!)
}

@MainActor
final class FakeLookup: GuardedChatLookup {
  var modes: [ChatID: ProtectionMode]

  init(_ modes: [ChatID: ProtectionMode] = [:]) {
    self.modes = modes
  }

  func protection(for chat: ChatID) -> ProtectionMode? { modes[chat] }
  func hasAnyGuarded(in messenger: Messenger) -> Bool {
    modes.keys.contains { $0.messenger == messenger }
  }
}

@MainActor
final class FakeScreen: SendTargetScreen {
  var context: SendContext?
  var replayResult = ReplayResult.sent
  var replayCount = 0
  var focusRestored = 0
  /// `nil`: the messenger cannot reopen chats. Otherwise whether reopening succeeds.
  var reopenResult: Bool?
  var reopenCount = 0

  init(_ context: SendContext? = nil) {
    self.context = context
  }

  func sendTarget(for gesture: SendGesture) -> SendTarget? {
    guard let context else { return nil }
    var reopenChat: SendTarget.ReopenChat?
    if let reopenResult {
      reopenChat = { [unowned self] completion in
        reopenCount += 1
        completion(reopenResult)
      }
    }
    return SendTarget(
      context: context,
      replay: { [unowned self] in
        replayCount += 1
        return replayResult
      },
      restoreFocus: { [unowned self] in focusRestored += 1 },
      reopenChat: reopenChat
    )
  }
}

@MainActor
final class FakePrompt: ConfirmationPrompt {
  var answer = false
  var asked: [SendAttempt] = []

  func confirm(_ attempt: SendAttempt) -> Bool {
    asked.append(attempt)
    return answer
  }
}

@MainActor
final class FakeFeedback: SendFeedback {
  var offered: [(attempt: SendAttempt, seconds: TimeInterval)] = []
  var pending: (@MainActor (UndoOutcome) -> Void)?
  var notices: [SendNotice] = []
  /// The last notice's "return and send" button, if it had one.
  var returnAndSend: (@MainActor () -> Void)?

  func offerUndo(
    for attempt: SendAttempt, seconds: TimeInterval,
    completion: @escaping @MainActor (UndoOutcome) -> Void
  ) {
    offered.append((attempt, seconds))
    pending = completion
  }

  func finishUndo(_ outcome: UndoOutcome) {
    finish(outcome)
  }

  func notify(_ notice: SendNotice, returnAndSend: (@MainActor () -> Void)?) {
    notices.append(notice)
    self.returnAndSend = returnAndSend
  }

  func finish(_ outcome: UndoOutcome) {
    pending?(outcome)
    pending = nil
  }
}

/// Collects scheduled work so tests decide when the prompt "appears".
@MainActor
final class ManualScheduler {
  private var queue: [@MainActor () -> Void] = []

  var schedule: SendGuardCoordinator.Scheduler {
    { [unowned self] work in queue.append(work) }
  }

  func runAll() {
    let work = queue
    queue.removeAll()
    work.forEach { $0() }
  }
}

/// A clock tests can move forward.
@MainActor
final class TestClock {
  var now = Date(timeIntervalSince1970: 1_000_000)

  func advance(minutes: Double) {
    now = now.addingTimeInterval(minutes * 60)
  }
}

func sendContext(
  to chat: ChatID?, in messenger: Messenger = .whatsApp, text: String = "Teklif ektedir",
  trigger: SendTrigger = .returnKey, isEmpty: Bool = false
) -> SendContext {
  SendContext(messenger: messenger, trigger: trigger, chat: chat, text: text, isEmpty: isEmpty)
}

let enter = SendGesture.returnKey(withCommand: false, targetProcess: 42)
let defaultBehavior = GuardBehavior(reaskAfterIdle: 15 * 60, undoDelay: 5)
