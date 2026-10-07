import Foundation
import Licensing

enum Links {
  /// Welp Pro checkout, subscription management and lost keys on the website. Opens in the
  /// browser.
  static let buyPro = URL(string: "https://www.getwelp.io/pro")!
}

/// Keeps the Welp Pro license in the user defaults, as JSON. It is verified on every launch.
struct UserDefaultsLicenseStore: LicenseStore {
  private static let key = "license"
  /// Where one-time-purchase keys were kept. They no longer unlock Welp Pro.
  private static let legacyKey = "licenseKey"

  func load() -> StoredLicense? {
    UserDefaults.standard.removeObject(forKey: Self.legacyKey)
    guard let data = UserDefaults.standard.data(forKey: Self.key) else { return nil }
    return try? JSONDecoder().decode(StoredLicense.self, from: data)
  }

  func save(_ license: StoredLicense?) {
    guard let license, let data = try? JSONEncoder().encode(license) else {
      UserDefaults.standard.removeObject(forKey: Self.key)
      return
    }
    UserDefaults.standard.set(data, forKey: Self.key)
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
