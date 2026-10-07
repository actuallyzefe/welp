import Licensing
import SharedKernel
import Testing

@testable import WelpProEdition

private final class InMemoryStore: LicenseStore, @unchecked Sendable {
  var license: StoredLicense?
  func load() -> StoredLicense? { license }
  func save(_ license: StoredLicense?) { self.license = license }
}

@MainActor
@Suite struct ProEditionTests {
  @Test func slackNeedsALicense() {
    let edition = ProEdition(licenses: LicenseService(store: InMemoryStore()))
    #expect(!edition.isAvailable(.slack))
  }

  @Test func whatsAppIsLeftToTheCore() {
    // The core always guards WhatsApp; the edition only answers for what it adds.
    let edition = ProEdition(licenses: LicenseService(store: InMemoryStore()))
    #expect(!edition.isAvailable(.whatsApp))
    #expect(!ProEdition.proMessengers.contains(.whatsApp))
  }

  @Test func addsTheSlackIntegration() {
    let edition = ProEdition(licenses: LicenseService(store: InMemoryStore()))
    let screens = edition.makeScreens(postReturnKey: { _ in })
    #expect(screens.map(\.messenger) == [.slack])
  }
}
