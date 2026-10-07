import Foundation
import Testing

@testable import WelpApp

@MainActor
@Suite struct LanguageSettingTests {
  private let domain = "welp-tests-\(UUID().uuidString)"
  private let defaults: UserDefaults
  private let setting: LanguageSetting

  init() {
    defaults = UserDefaults(suiteName: domain)!
    setting = LanguageSetting(defaults: defaults, domain: domain, available: ["tr", "Base", "en"])
  }

  private func cleanUp() {
    defaults.removePersistentDomain(forName: domain)
  }

  @Test func offersTheTranslatedLanguages() {
    #expect(setting.available == ["en", "tr"])
  }

  @Test func followsTheMacUntilALanguageIsChosen() {
    defer { cleanUp() }
    #expect(setting.selection == nil)
  }

  @Test func remembersTheChosenLanguageTheWayMacOSReadsIt() {
    defer { cleanUp() }
    setting.select("tr")

    #expect(setting.selection == "tr")
    #expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] as? [String] == ["tr"])
  }

  @Test func goesBackToTheMacLanguage() {
    defer { cleanUp() }
    setting.select("tr")
    setting.select(nil)

    #expect(setting.selection == nil)
    #expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] == nil)
  }

  @Test func understandsRegionVariantsSetInSystemSettings() {
    defer { cleanUp() }
    defaults.set(["tr-TR"], forKey: "AppleLanguages")
    #expect(setting.selection == "tr")
  }

  @Test func ignoresLanguagesWelpIsNotTranslatedInto() {
    defer { cleanUp() }
    defaults.set(["ja-JP"], forKey: "AppleLanguages")
    #expect(setting.selection == nil)
  }

  @Test func namesEachLanguageInItself() {
    #expect(LanguageSetting.displayName(of: "en") == "English")
    #expect(LanguageSetting.displayName(of: "tr") == "Türkçe")
  }
}
