import AppKit
import ApplicationServices

/// The Accessibility permission, required both to read WhatsApp and to intercept input.
@MainActor
class AccessibilityPermission {
  private static let settingsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
  private var pollTimer: Timer?

  var isGranted: Bool { AXIsProcessTrusted() }

  /// Runs `action` once the permission is granted, asking the user for it if needed.
  func whenGranted(_ action: @escaping @MainActor () -> Void) {
    guard !isGranted else {
      action()
      return
    }
    requestFromUser()
    pollTimer?.invalidate()
    pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.isGranted else { return }
        self.pollTimer?.invalidate()
        self.pollTimer = nil
        action()
      }
    }
  }

  func openSettings() {
    NSWorkspace.shared.open(Self.settingsURL)
  }

  private func requestFromUser() {
    // Literal key: the `kAXTrustedCheckOptionPrompt` global is not concurrency-safe.
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }
}
