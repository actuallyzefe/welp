import AppKit
import SharedKernel

/// Welp's own interface language, if the user picked one instead of the Mac's.
///
/// Stored exactly like System Settings › General › Language & Region › Applications stores
/// it (`AppleLanguages` in the app's own defaults domain), so both places always agree.
/// macOS reads it at launch: a change takes effect after a relaunch.
@MainActor
struct LanguageSetting {
  private static let key = "AppleLanguages"

  private let defaults: UserDefaults
  private let domain: String
  /// The languages Welp is translated into, e.g. `["en", "tr"]`.
  let available: [String]

  init(
    defaults: UserDefaults = .standard,
    domain: String = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName,
    available: [String] = Bundle.localization.localizations
  ) {
    self.defaults = defaults
    self.domain = domain
    self.available = available.filter { $0 != "Base" }.sorted()
  }

  /// The chosen language (one of `available`), or `nil` to follow the Mac.
  var selection: String? {
    // Only the app's own domain: the global one holds the Mac's language list.
    guard let preferred = defaults.persistentDomain(forName: domain)?[Self.key] as? [String],
      !preferred.isEmpty
    else { return nil }
    // System Settings stores region variants such as "tr-TR"; match them like macOS does.
    // That API falls back to some available language when nothing matches, so check.
    guard
      let match = Bundle.preferredLocalizations(from: available, forPreferences: preferred).first
    else { return nil }
    let code = Locale.Language(identifier: match).languageCode
    return preferred.contains { Locale.Language(identifier: $0).languageCode == code } ? match : nil
  }

  func select(_ language: String?) {
    if let language {
      defaults.set([language], forKey: Self.key)
    } else {
      defaults.removeObject(forKey: Self.key)
    }
  }

  /// A language's name in that language ("English", "Türkçe"), so people can find their
  /// own language whatever the interface is currently in.
  static func displayName(of language: String) -> String {
    let locale = Locale(identifier: language)
    let name = locale.localizedString(forIdentifier: language) ?? language
    return name.prefix(1).uppercased(with: locale) + name.dropFirst()
  }
}

/// Quits Welp and opens it again, e.g. to apply a new language.
@MainActor
enum Relauncher {
  static func relaunch(logger: any AppLogger) {
    let app = Bundle.main.bundleURL
    // A helper waits until this process has exited, so two instances never run (and
    // intercept input) at the same time. Arguments are passed separately, not interpolated.
    let helper = Process()
    helper.executableURL = URL(filePath: "/bin/sh")
    helper.arguments = [
      "-c", #"while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open "$2""#,
      "relaunch", String(ProcessInfo.processInfo.processIdentifier), app.path(),
    ]
    do {
      guard app.pathExtension == "app" else { throw CocoaError(.executableNotLoadable) }
      try helper.run()
    } catch {
      // Better to keep protecting with the old language than to quit and not come back.
      logger.error("Could not relaunch: \(error)")
      return
    }
    NSApp.terminate(nil)
  }
}
