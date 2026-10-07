import SharedKernel
import Testing

@Suite struct ChatNameTests {
  @Test func normalizesWhitespaceAndInvisibleCharacters() {
    let leftToRightMark = "\u{200E}"
    let name = ChatName("  \(leftToRightMark)Müşteri   Grubu\n")
    #expect(name?.value == "Müşteri Grubu")
  }

  @Test func comparesCaseInsensitivelyWithTurkishRules() {
    #expect(ChatName("İSTANBUL EKİBİ") == ChatName("istanbul ekibi"))
    #expect(ChatName("Acme") != ChatName("Acme Ltd"))
  }

  @Test func rejectsEmptyAndOversizedNames() {
    #expect(ChatName("   ") == nil)
    #expect(ChatName(nil) == nil)
    #expect(ChatName(String(repeating: "x", count: ChatName.maxLength + 1)) == nil)
  }

  @Test func equalNamesHashEqually() {
    let names: Set = [ChatName("2T1K"), ChatName("2t1k")]
    #expect(names.count == 1)
  }
}

@Suite struct ChatIDTests {
  @Test func distinguishesMessengersAndWorkspaces() {
    let name = ChatName("general")!
    let acme = ChatID(messenger: .slack, workspace: ChatName("Acme"), name: name)

    #expect(acme == ChatID(messenger: .slack, workspace: ChatName("ACME"), name: name))
    #expect(acme != ChatID(messenger: .slack, workspace: ChatName("Beta"), name: name))
    #expect(acme != ChatID(messenger: .whatsApp, name: name))
  }

  @Test func describesItselfForPeople() {
    let slack = ChatID(messenger: .slack, workspace: ChatName("Acme"), name: ChatName("test")!)
    #expect(slack.description == "Slack › Acme › test")
    #expect(ChatID(messenger: .whatsApp, name: ChatName("2T1K")!).description == "WhatsApp › 2T1K")
  }
}
