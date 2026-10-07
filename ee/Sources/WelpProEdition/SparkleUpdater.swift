@preconcurrency import Sparkle
import WelpApp

/// Updates the official app with Sparkle, from the feed in its Info.plist (`SUFeedURL`).
/// Updates are EdDSA-signed (`SUPublicEDKey`) and Developer ID notarized. Sparkle asks for
/// permission before the first automatic check and sends no system profile.
@MainActor
final class SparkleUpdater: AppUpdater {
  private let controller = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

  /// Only builds that carry a feed can update; development builds don't.
  static var isConfigured: Bool {
    Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
  }

  var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

  var automaticallyChecksForUpdates: Bool {
    get { controller.updater.automaticallyChecksForUpdates }
    set { controller.updater.automaticallyChecksForUpdates = newValue }
  }

  func checkForUpdates() {
    controller.checkForUpdates(nil)
  }
}
