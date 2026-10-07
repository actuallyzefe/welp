import Testing

@testable import SlackAccessibility

@Suite struct SlackWindowTitleTests {
  @Test func parsesAChannelTitle() {
    let title = SlackWindowTitle("test (Channel) - Sentez App Studio - 5 new items - Slack")
    #expect(title?.conversation == "test")
    #expect(title?.workspace == "Sentez App Studio")
  }

  @Test func parsesDirectMessagesAndOtherLanguages() {
    #expect(SlackWindowTitle("Ali Veli (DM) - Acme - Slack")?.conversation == "Ali Veli")
    #expect(SlackWindowTitle("genel (Kanal) - Acme - Slack")?.conversation == "genel")
  }

  @Test func readsOnlyTheWorkspaceOfViewsThatAreNotASingleConversation() {
    let activity = SlackWindowTitle("Activity - Acme - 8 new items - Slack")
    #expect(activity?.conversation == nil)
    #expect(activity?.workspace == "Acme")
    #expect(SlackWindowTitle("Threads - Acme - Slack")?.conversation == nil)
    #expect(SlackWindowTitle(" (Channel) - Acme - Slack")?.conversation == nil)
  }

  @Test func rejectsTitlesWithoutAWorkspace() {
    #expect(SlackWindowTitle("Slack") == nil)
    #expect(SlackWindowTitle("test (Channel) - Acme") == nil)
    #expect(SlackWindowTitle("test (Channel) -  - Slack") == nil)
  }
}
