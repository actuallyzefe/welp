import Foundation
import SendGuard
import SharedKernel
import Testing

@MainActor
@Suite struct SendGuardCoordinatorTests {
  private let screen = FakeScreen()
  private let prompt = FakePrompt()
  private let feedback = FakeFeedback()
  private let scheduler = ManualScheduler()
  private let clock = TestClock()
  private let memory = ApprovalMemory()

  private func makeCoordinator(_ modes: [ChatID: ProtectionMode]) -> SendGuardCoordinator {
    SendGuardCoordinator(
      policy: SendGuardPolicy(
        lookup: FakeLookup(modes), memory: memory, behavior: { defaultBehavior }),
      memory: memory,
      screen: screen,
      prompt: prompt,
      feedback: feedback,
      logger: NullLogger(),
      clock: { [clock] in clock.now },
      schedule: scheduler.schedule
    )
  }

  @Test func passesGesturesThatAreNotSends() {
    #expect(makeCoordinator([:]).handle(enter) == .pass)
  }

  @Test func confirmsAndReplaysInEveryMessageMode() {
    screen.context = sendContext(to: TestChats.customer)
    prompt.answer = true
    let coordinator = makeCoordinator([TestChats.customer: .everyMessage])

    #expect(coordinator.handle(enter) == .swallow)
    scheduler.runAll()
    #expect(screen.replayCount == 1)
    #expect(screen.focusRestored == 1)

    #expect(coordinator.handle(enter) == .swallow)
    scheduler.runAll()
    #expect(prompt.asked.count == 2)
  }

  @Test func asksOnlyForTheFirstMessageWhileYouStay() {
    screen.context = sendContext(to: TestChats.customer)
    prompt.answer = true
    let coordinator = makeCoordinator([TestChats.customer: .firstMessage])
    memory.activeChatChanged(in: .whatsApp, to: TestChats.customer)

    #expect(coordinator.handle(enter) == .swallow)
    scheduler.runAll()
    #expect(coordinator.handle(enter) == .pass)
    #expect(prompt.asked.count == 1)

    memory.activeChatChanged(in: .whatsApp, to: TestChats.friend)
    memory.activeChatChanged(in: .whatsApp, to: TestChats.customer)
    #expect(coordinator.handle(enter) == .swallow)
  }

  @Test func doesNotRememberACancelledFirstMessage() {
    screen.context = sendContext(to: TestChats.customer)
    let coordinator = makeCoordinator([TestChats.customer: .firstMessage])

    #expect(coordinator.handle(enter) == .swallow)
    scheduler.runAll()
    #expect(screen.replayCount == 0)
    #expect(coordinator.handle(enter) == .swallow)
  }

  @Test func undoModeSendsWhenTheCountdownEnds() {
    screen.context = sendContext(to: TestChats.customer)
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    #expect(coordinator.handle(enter) == .swallow)
    scheduler.runAll()
    #expect(feedback.offered.first?.seconds == 5)
    #expect(prompt.asked.isEmpty)

    feedback.finish(.send)
    #expect(screen.replayCount == 1)
    #expect(screen.focusRestored == 0)  // Focus never left the messenger.
  }

  @Test func undoModeDropsTheMessageOnUndo() {
    screen.context = sendContext(to: TestChats.customer)
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    _ = coordinator.handle(enter)
    scheduler.runAll()
    feedback.finish(.undo)
    #expect(screen.replayCount == 0)
    #expect(coordinator.handle(enter) == .swallow)  // Ready for the next attempt.
  }

  @Test func escapeUndoesTheHeldMessage() {
    screen.context = sendContext(to: TestChats.customer)
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    #expect(coordinator.handleEscape() == .pass)  // Nothing held: Escape is left alone.
    _ = coordinator.handle(enter)
    scheduler.runAll()
    #expect(coordinator.handleEscape() == .swallow)
    #expect(screen.replayCount == 0)
    #expect(coordinator.handleEscape() == .pass)  // Undone; the countdown is over.
  }

  @Test func sendingTheHeldMessageAgainSkipsTheUndoWait() {
    screen.context = sendContext(to: TestChats.customer)
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    #expect(coordinator.handle(enter) == .swallow)
    scheduler.runAll()
    #expect(coordinator.handle(enter) == .swallow)
    #expect(screen.replayCount == 1)
    #expect(feedback.offered.count == 1)

    #expect(coordinator.handle(enter) == .swallow)  // A new message starts a new countdown.
    scheduler.runAll()
    #expect(feedback.offered.count == 2)
  }

  @Test func swallowsOtherSendsWhileADecisionIsPending() {
    screen.context = sendContext(to: TestChats.customer)
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    #expect(coordinator.handle(enter) == .swallow)
    scheduler.runAll()
    screen.context = sendContext(to: TestChats.customer, text: "Something else")
    #expect(coordinator.handle(enter) == .swallow)
    scheduler.runAll()
    #expect(screen.replayCount == 0)
    #expect(feedback.offered.count == 1)
  }

  @Test func reportsWhenTheChatChangedBeforeTheReplay() {
    screen.context = sendContext(to: TestChats.customer)
    screen.replayResult = .targetChanged
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    _ = coordinator.handle(enter)
    scheduler.runAll()
    feedback.finish(.send)
    #expect(feedback.notices == [.targetChanged(feedback.offered[0].attempt)])
    #expect(feedback.returnAndSend == nil)  // This screen cannot reopen chats.
  }

  @Test func returnsToTheChatAndSendsOnRequest() {
    screen.context = sendContext(to: TestChats.customer)
    screen.replayResult = .targetChanged
    screen.reopenResult = true
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    _ = coordinator.handle(enter)
    scheduler.runAll()
    feedback.finish(.send)
    #expect(screen.replayCount == 1)

    screen.replayResult = .sent
    feedback.returnAndSend?()
    #expect(screen.reopenCount == 1)
    #expect(screen.replayCount == 2)
    #expect(feedback.notices.count == 1)
  }

  @Test func reportsWhenTheChatCannotBeReopened() {
    screen.context = sendContext(to: TestChats.customer)
    screen.replayResult = .targetChanged
    screen.reopenResult = false
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    _ = coordinator.handle(enter)
    scheduler.runAll()
    feedback.finish(.send)
    feedback.returnAndSend?()
    #expect(screen.replayCount == 1)  // Nothing is sent anywhere else.
    #expect(feedback.notices.last == .sendFailed)
  }

  @Test func reportsWhenTheReplayFails() {
    screen.context = sendContext(to: TestChats.customer)
    screen.replayResult = .failed
    let coordinator = makeCoordinator([TestChats.customer: .undo])

    _ = coordinator.handle(enter)
    scheduler.runAll()
    feedback.finish(.send)
    #expect(feedback.notices == [.sendFailed])
  }
}

@MainActor
@Suite struct CompositeSendTargetScreenTests {
  @Test func usesTheFirstScreenThatRecognisesTheGesture() {
    let slack = FakeScreen(sendContext(to: TestChats.slackGeneral, in: .slack))
    let composite = CompositeSendTargetScreen([FakeScreen(), slack, FakeScreen()])
    #expect(composite.sendTarget(for: enter)?.context.messenger == .slack)
  }

  @Test func returnsNilWhenNoScreenRecognisesIt() {
    let composite = CompositeSendTargetScreen([FakeScreen(), FakeScreen()])
    #expect(composite.sendTarget(for: .click(at: .zero)) == nil)
  }
}
