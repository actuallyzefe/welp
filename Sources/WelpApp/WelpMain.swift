import AppKit
import InputInterception

/// Starts Welp with the given edition: `CoreEdition()` for the open-source core, or
/// Welp Pro's edition for the official app.
@MainActor
public enum WelpApplication {
  public static func run(edition: any WelpEdition) {
    if CommandLine.arguments.contains("--diagnose") {
      runDiagnostics(edition: edition)
      return
    }
    #if DEBUG
      if let index = CommandLine.arguments.firstIndex(of: "--render-settings"),
        CommandLine.arguments.indices.contains(index + 1)
      {
        _ = NSApplication.shared
        do {
          try SettingsSnapshots.render(to: URL(filePath: CommandLine.arguments[index + 1]))
        } catch {
          print("Render failed: \(error)")
        }
        return
      }
    #endif

    let app = NSApplication.shared
    let delegate = AppDelegate(edition: edition)
    app.delegate = delegate
    app.setActivationPolicy(.accessory)  // Menu bar only, no Dock icon.
    app.mainMenu = MainMenu.make()  // Shown only while the settings window is open.
    app.run()
  }

  /// Prints what Welp can currently see in each messenger. Useful after UI changes.
  /// Developer-facing (pasted into issues), so it is deliberately not localized.
  private static func runDiagnostics(edition: any WelpEdition) {
    print(
      "Accessibility permission: \(AccessibilityPermission().isGranted ? "granted" : "MISSING")")
    for screen in AppDelegate.makeScreens(edition: edition) {
      print(screen.diagnosticReport())
    }
  }
}
