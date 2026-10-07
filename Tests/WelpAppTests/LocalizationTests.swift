import Foundation
import SendGuard
import SharedKernel
import Testing

@testable import WelpApp

/// Checks the compiled translations as the app loads them, not just the catalog's JSON.
@Suite struct LocalizationTests {
  /// The bundle for one language, regardless of the test runner's own language.
  private func bundle(_ language: String) throws -> Bundle {
    let path = try #require(Bundle.localization.path(forResource: language, ofType: "lproj"))
    return try #require(Bundle(path: path))
  }

  private func localized(_ key: String, _ language: String) throws -> String {
    try bundle(language).localizedString(forKey: key, value: "<missing>", table: nil)
  }

  @Test func shipsEveryDeclaredLanguage() throws {
    let localizations = Set(Bundle.localization.localizations)
    #expect(localizations.isSuperset(of: ["en", "tr"]))
  }

  @Test func loadsTurkishTranslations() throws {
    #expect(try localized("Are you sure?", "tr") == "Emin misin?")
    #expect(try localized("Settings…", "tr") == "Ayarlar…")
  }

  @Test(arguments: [
    ("en", 1, "1 chat"), ("en", 3, "3 chats"),
    ("tr", 1, "1 sohbet"), ("tr", 3, "3 sohbet"),
  ])
  func pluralizesChatCounts(language: String, count: Int, expected: String) throws {
    let format = try localized("%lld chats", language)
    #expect(String(format: format, locale: Locale(identifier: language), count) == expected)
  }

  @Test func translationsMayMoveArguments() throws {
    let format = try localized("Protect “%@”", "tr")
    #expect(String(format: format, "genel") == "“genel” sohbetini koru")
  }

  // MARK: Confirmation prompt (in the source language, as the test runner has no other)

  @Test func namesTheChatInTheConfirmation() {
    let slack = ChatID(messenger: .slack, workspace: ChatName("Acme"), name: ChatName("general")!)
    let attempt = SendAttempt(
      messenger: .slack, chat: slack, text: "Akşam maç var mı?", trigger: .returnKey)
    let message = ConfirmationMessage(for: attempt)

    #expect(message.title == "Are you sure?")
    #expect(message.detail.contains("Slack › Acme › general"))
    #expect(message.detail.contains("Akşam maç var mı?"))
    #expect(message.confirmLabel == "Send")
    #expect(message.cancelLabel == "Cancel")
  }

  @Test func describesUnknownChatsAndAttachments() {
    let attempt = SendAttempt(messenger: .whatsApp, chat: nil, text: "", trigger: .returnKey)
    let message = ConfirmationMessage(for: attempt)

    #expect(message.detail.contains("WhatsApp: couldn’t tell which chat"))
    #expect(message.detail.contains("Attachment / media"))
  }

  @Test func describesEveryNotice() {
    let attempt = SendAttempt(
      messenger: .whatsApp, chat: ChatID(messenger: .whatsApp, name: ChatName("2T1K")!),
      text: "Teklif ektedir", trigger: .returnKey)
    let changed = SendNotice.targetChanged(attempt).message
    #expect(changed != SendNotice.sendFailed.message)
    #expect(changed.contains("2T1K"))
  }
}
