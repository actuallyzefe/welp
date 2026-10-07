import AppKit
import SendGuard
import SwiftUI

/// The "Are you sure?" prompt, as a card right above the guarded chat's message box.
///
/// It is modal like an alert: the send waits for an answer. Return sends, since the prompt
/// itself is the pause; Escape or "Cancel" stops the message. A Return that arrives too fast
/// to be a decision (a double press, or the key held down) is ignored.
@MainActor
struct ComposerConfirmationPrompt: ConfirmationPrompt {
  /// A Return sooner than this after the prompt appears is the same keystroke bouncing or a
  /// double press, not someone who read the prompt.
  private static let minimumReadingTime: TimeInterval = 0.35

  let anchor: ComposerAnchor

  func confirm(_ attempt: SendAttempt) -> Bool {
    let panel = KeyablePanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: true)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .modalPanel
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    let shownAt = Date()
    let host = NSHostingView(
      rootView: ConfirmationCard(attempt: attempt) { send in
        if send, let event = NSApp.currentEvent, event.type == .keyDown,
          event.isARepeat || Date().timeIntervalSince(shownAt) < Self.minimumReadingTime
        {
          return
        }
        NSApp.stopModal(withCode: send ? .OK : .cancel)
      })
    panel.contentView = host
    panel.setFrame(
      anchor.frame(for: host.fittingSize, inset: SendPromptLayout.inset, fallback: .center),
      display: true)

    // A non-activating panel takes the keyboard from the messenger without activating Welp,
    // so Welp's other windows (an open settings window) stay behind the messenger.
    panel.makeKeyAndOrderFront(nil)
    let response = NSApp.runModal(for: panel)
    panel.orderOut(nil)
    return response == .OK
  }
}

/// A borderless panel that can still take the keyboard, for Return and Escape.
private final class KeyablePanel: NSPanel {
  override var canBecomeKey: Bool { true }

  /// Escape cancels, like in an alert.
  override func cancelOperation(_ sender: Any?) {
    NSApp.stopModal(withCode: .cancel)
  }
}
