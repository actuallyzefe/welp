import GuardedChats
import SharedKernel
import Testing

@Suite struct GuardedChatListTests {
  private let customer = TestChats.whatsApp("Acme Müşteri")

  @Test func setsAndRemovesWithoutMutatingTheOriginal() {
    let empty = GuardedChatList.empty
    let guarded = empty.setting(customer, to: .everyMessage)

    #expect(empty.isEmpty)
    #expect(guarded.mode(for: TestChats.whatsApp("ACME MÜŞTERİ")) == .everyMessage)
    #expect(guarded.removing(customer).isEmpty)
  }

  @Test func changesTheModeOfAGuardedChat() {
    let list = GuardedChatList([TestChats.guarded(customer, .firstMessage)])
    #expect(list.setting(customer, to: .undo).mode(for: customer) == .undo)
    #expect(list.setting(customer, to: .undo).count == 1)
  }

  @Test func knowsWhichMessengersHaveGuards() {
    let list = GuardedChatList([TestChats.guarded(TestChats.slack("general"))])
    #expect(list.contains(anyIn: .slack))
    #expect(!list.contains(anyIn: .whatsApp))
  }

  @Test func sortsByMessengerWorkspaceAndName() {
    let list = GuardedChatList(
      [
        TestChats.whatsApp("Zeytin"), TestChats.slack("b", in: "Beta"),
        TestChats.slack("z", in: "Acme"), TestChats.whatsApp("Çiçek"),
      ].map { TestChats.guarded($0) })
    #expect(
      list.sorted.map(\.id.description) == [
        "Slack › Acme › z", "Slack › Beta › b", "WhatsApp › Çiçek", "WhatsApp › Zeytin",
      ])
  }
}
