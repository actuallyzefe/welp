import Foundation
import Licensing
import Testing

@testable import WelpProEdition

@Suite struct UserDefaultsLicenseStoreTests {
  private let domain = "welp-tests-\(UUID().uuidString)"
  private var store: UserDefaultsLicenseStore { UserDefaultsLicenseStore(suiteName: domain) }
  private var defaults: UserDefaults { UserDefaults(suiteName: domain)! }

  private func cleanUp() {
    defaults.removePersistentDomain(forName: domain)
  }

  @Test func keepsTheLicenseBetweenLaunches() {
    defer { cleanUp() }
    let license = StoredLicense(
      key: "WELP-key", lease: "WELP-lease", latestTime: Date(timeIntervalSince1970: 1),
      hasEnded: false)
    store.save(license)

    // A new store stands for the next launch.
    #expect(UserDefaultsLicenseStore(suiteName: domain).load() == license)
  }

  @Test func removesTheLicenseOnlyWhenAskedTo() {
    defer { cleanUp() }
    store.save(StoredLicense(key: "WELP-key"))
    store.save(nil)

    #expect(store.load() == nil)
    #expect(defaults.data(forKey: "license") == nil)
  }

  @Test func leavesAnUnreadableLicenseInPlace() {
    defer { cleanUp() }
    defaults.set(Data("not a license".utf8), forKey: "license")

    #expect(store.load() == nil)
    #expect(defaults.data(forKey: "license") == Data("not a license".utf8))
  }

  @Test func dropsTheOneTimePurchaseKey() {
    defer { cleanUp() }
    defaults.set("WELP-old", forKey: "licenseKey")

    _ = store.load()
    #expect(defaults.string(forKey: "licenseKey") == nil)
  }
}
