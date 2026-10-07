import Foundation

extension Bundle {
  /// Where Welp's translations live.
  ///
  /// `build-app.sh` puts SwiftPM's resource bundle in `Welp.app/Contents/Resources`, because
  /// the generated `Bundle.module` only looks next to the `.app` (where code signing does not
  /// allow it) and would otherwise fall back to the absolute path of the build directory.
  /// For command-line builds the bundle sits next to the executable, which `resourceURL`
  /// also resolves to. Use it for every user-facing string:
  ///
  ///     String(localized: "Settings…", bundle: .localization, comment: "Menu bar item")
  static let localization: Bundle =
    Bundle.main.resourceURL
    .flatMap { Bundle(url: $0.appending(path: "Welp_WelpApp.bundle")) } ?? Bundle.module
}
