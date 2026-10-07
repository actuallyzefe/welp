import Foundation
import SendGuard
import SharedKernel
import Testing

@MainActor
@Suite struct SendGuardPolicyTests {
  private let memory = ApprovalMemory()
  private let now = Date(timeIntervalSince1970: 0)

  private func policy(_ modes: [ChatID: ProtectionMode]) -> SendGuardPolicy {
    SendGuardPolicy(lookup: FakeLookup(modes), memory: memory, behavior: { defaultBehavior })
  }

  private func attempt(_ chat: ChatID?, in messenger: Messenger = .whatsApp) -> SendAttempt {
    SendAttempt(messenger: messenger, chat: chat, text: "Teklif ektedir", trigger: .returnKey)
  }

  @Test func allowsUnguardedChatsAndEmptySends() {
    let policy = policy([TestChats.customer: .everyMessage])
    #expect(policy.evaluate(sendContext(to: TestChats.friend), at: now) == .allow)
    #expect(policy.evaluate(sendContext(to: TestChats.customer, isEmpty: true), at: now) == .allow)
  }

  @Test func everyMessageModeAlwaysAsks() {
    let policy = policy([TestChats.customer: .everyMessage])
    memory.recordApproval(of: TestChats.customer, at: now)
    #expect(
      policy.evaluate(sendContext(to: TestChats.customer), at: now)
        == .confirm(attempt(TestChats.customer), remember: false))
  }

  @Test func firstMessageModeAsksOnceThenRemembers() {
    let policy = policy([TestChats.customer: .firstMessage])
    #expect(
      policy.evaluate(sendContext(to: TestChats.customer), at: now)
        == .confirm(attempt(TestChats.customer), remember: true))

    memory.recordApproval(of: TestChats.customer, at: now)
    #expect(
      policy.evaluate(sendContext(to: TestChats.customer), at: now + 60)
        == .allowApproved(TestChats.customer))
  }

  @Test func firstMessageModeAsksAgainAfterSilence() {
    let policy = policy([TestChats.customer: .firstMessage])
    memory.recordApproval(of: TestChats.customer, at: now)
    #expect(
      policy.evaluate(sendContext(to: TestChats.customer), at: now + 16 * 60)
        == .confirm(attempt(TestChats.customer), remember: true))
  }

  @Test func undoModeDelaysWithTheConfiguredDuration() {
    let policy = policy([TestChats.customer: .undo])
    #expect(
      policy.evaluate(sendContext(to: TestChats.customer), at: now)
        == .delay(attempt(TestChats.customer), seconds: 5))
  }

  @Test func unknownChatsAreTreatedStrictlyWithinTheSameMessenger() {
    let policy = policy([TestChats.slackGeneral: .undo])
    #expect(
      policy.evaluate(sendContext(to: nil, in: .slack), at: now)
        == .confirm(attempt(nil, in: .slack), remember: false))
    #expect(policy.evaluate(sendContext(to: nil, in: .whatsApp), at: now) == .allow)
  }
}
