import AppKit
import SharedKernel

/// Shown when someone tries to guard a chat in a messenger that needs Welp Pro.
///
/// Kept short: what is free (WhatsApp) and what Pro adds.
@MainActor
enum UpgradePrompt {
  static func show(for messenger: Messenger, openPlan: @escaping @MainActor () -> Void) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = String(
      localized: "Protecting \(messenger.displayName) chats is part of Welp Pro",
      bundle: .welpPro,
      comment: "Alert title. The argument is an app name, e.g. Slack.")
    alert.informativeText = String(
      localized: "WhatsApp stays free. Get Welp Pro to protect Slack chats too.",
      bundle: .welpPro, comment: "Alert text when a Pro app's chat is protected without a license.")
    alert.addButton(withTitle: .getWelpPro)
    alert.addButton(
      withTitle: String(
        localized: "Enter License Key…", bundle: .welpPro,
        comment: "Alert button that opens the license settings."))
    alert.addButton(
      withTitle: String(localized: "Not Now", bundle: .welpPro, comment: "Alert button."))

    NSApp.activate(ignoringOtherApps: true)
    let respond = { (response: NSApplication.ModalResponse) in
      switch response {
      case .alertFirstButtonReturn: NSWorkspace.shared.open(Links.buyPro)
      case .alertSecondButtonReturn: openPlan()
      default: break
      }
    }
    // From the settings (an "Unlock" button), a sheet on that window: a modal loop started
    // inside a SwiftUI button's action leaves the window frozen.
    if let window = NSApp.keyWindow ?? NSApp.mainWindow {
      alert.beginSheetModal(for: window, completionHandler: respond)
    } else {
      respond(alert.runModal())
    }
  }
}
