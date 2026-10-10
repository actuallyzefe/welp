import Foundation
import Licensing
import os

enum Links {
  /// Welp Pro checkout, subscription management and lost keys on the website. Opens in the
  /// browser.
  static let buyPro = URL(string: "https://www.getwelp.io/pro")!
}

/// Keeps the Welp Pro license in the user defaults, as JSON. It is verified on every launch.
///
/// Losing it means re-entering the key, so it is only ever deleted on purpose (Remove
/// License), and what happens to it is logged, never the key itself.
struct UserDefaultsLicenseStore: LicenseStore {
  private static let key = "license"
  /// Where one-time-purchase keys were kept. They no longer unlock Welp Pro.
  private static let legacyKey = "licenseKey"
  private static let logger = Logger(subsystem: "dev.karakanli.welp", category: "license")

  /// `nil` for the app's own defaults. A name (not a `UserDefaults`, which isn't `Sendable`)
  /// so tests can use a domain of their own.
  private let suiteName: String?

  init(suiteName: String? = nil) {
    self.suiteName = suiteName
  }

  private var defaults: UserDefaults {
    suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
  }

  func load() -> StoredLicense? {
    defaults.removeObject(forKey: Self.legacyKey)
    guard let data = defaults.data(forKey: Self.key) else {
      Self.logger.info("No license stored")
      return nil
    }
    // An unreadable license stays where it is: a later version may read it, and only
    // entering a key again replaces it.
    guard let license = try? JSONDecoder().decode(StoredLicense.self, from: data) else {
      Self.logger.error("The stored license is unreadable")
      return nil
    }
    Self.logger.info("License loaded")
    return license
  }

  func save(_ license: StoredLicense?) {
    guard let license else {
      defaults.removeObject(forKey: Self.key)
      Self.logger.info("License removed")
      return
    }
    // A failed write keeps the previous license rather than deleting it.
    guard let data = try? JSONEncoder().encode(license) else {
      Self.logger.error("Could not save the license; keeping the previous one")
      return
    }
    defaults.set(data, forKey: Self.key)
  }
}

extension Bundle {
  /// Welp Pro's translations. Like the core's, `build-app.sh` puts the resource bundle in
  /// `Welp.app/Contents/Resources`; command-line builds find it next to the executable.
  static let welpPro: Bundle =
    Bundle.main.resourceURL
    .flatMap { Bundle(url: $0.appending(path: "Welp_WelpProEdition.bundle")) } ?? Bundle.module
}

extension String {
  static var getWelpPro: String {
    String(
      localized: "Get Welp Pro", bundle: .welpPro,
      comment: "Button that opens the Welp Pro checkout on the website.")
  }
}
