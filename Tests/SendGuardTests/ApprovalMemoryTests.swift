import Foundation
import SendGuard
import SharedKernel
import Testing

@MainActor
@Suite struct ApprovalMemoryTests {
  private let memory = ApprovalMemory()
  private let start = Date(timeIntervalSince1970: 0)

  @Test func remembersAnApprovalWhileYouStayInTheChat() {
    memory.recordApproval(of: TestChats.customer, at: start)
    memory.activeChatChanged(in: .whatsApp, to: TestChats.customer)
    #expect(memory.isApproved(TestChats.customer, at: start + 60, idleLimit: nil))
  }

  @Test func forgetsTheApprovalWhenYouLeaveAndReturn() {
    memory.recordApproval(of: TestChats.customer, at: start)
    memory.activeChatChanged(in: .whatsApp, to: TestChats.friend)
    memory.activeChatChanged(in: .whatsApp, to: TestChats.customer)
    #expect(!memory.isApproved(TestChats.customer, at: start, idleLimit: nil))
  }

  @Test func keepsMessengersIndependent() {
    memory.recordApproval(of: TestChats.customer, at: start)
    memory.activeChatChanged(in: .slack, to: TestChats.slackGeneral)
    #expect(memory.isApproved(TestChats.customer, at: start, idleLimit: nil))
  }

  @Test func expiresAfterSilence() {
    memory.recordApproval(of: TestChats.customer, at: start)
    #expect(memory.isApproved(TestChats.customer, at: start + 14 * 60, idleLimit: 15 * 60))
    #expect(!memory.isApproved(TestChats.customer, at: start + 15 * 60, idleLimit: 15 * 60))
  }

  @Test func activityRestartsTheIdleTimer() {
    memory.recordApproval(of: TestChats.customer, at: start)
    memory.recordActivity(in: TestChats.customer, at: start + 10 * 60)
    #expect(memory.isApproved(TestChats.customer, at: start + 20 * 60, idleLimit: 15 * 60))
  }
}
