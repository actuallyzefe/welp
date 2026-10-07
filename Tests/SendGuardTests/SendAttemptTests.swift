import SendGuard
import SharedKernel
import Testing

@Suite struct SendAttemptTests {
  private func attempt(_ text: String, to chat: ChatID? = TestChats.customer) -> SendAttempt {
    SendAttempt(messenger: .whatsApp, chat: chat, text: text, trigger: .returnKey)
  }

  @Test func compactsWhitespaceInThePreview() {
    #expect(attempt(" merhaba\n\n  dünya ").preview == "merhaba dünya")
  }

  @Test func truncatesLongMessages() {
    let preview = attempt(String(repeating: "a", count: 1000)).preview
    #expect(preview.count == SendAttempt.previewMaxLength)
    #expect(preview.hasSuffix("…"))
  }
}
