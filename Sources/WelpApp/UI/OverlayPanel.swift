import AppKit
import SwiftUI

/// A floating, borderless panel that never takes focus away from the messenger.
@MainActor
enum OverlayPanel {
  static func make(interactive: Bool) -> NSPanel {
    let panel = NSPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .floating
    panel.hidesOnDeactivate = false  // Welp itself is never the active app.
    panel.isReleasedWhenClosed = false
    panel.ignoresMouseEvents = !interactive
    panel.becomesKeyOnlyIfNeeded = true
    panel.collectionBehavior = [
      .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]
    return panel
  }
}

/// Hosting view whose buttons respond to the first click in a non-key panel.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension CGRect {
  /// Converts an Accessibility (top-left origin) rect to AppKit screen coordinates.
  var flippedToAppKit: CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
    return CGRect(x: minX, y: primaryHeight - maxY, width: width, height: height)
  }
}
