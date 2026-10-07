import AppKit
import SharedKernel
import SwiftUI

/// The "Acme Customer · First message" badge pinned above a guarded chat's message box.
/// Click-through, so it never gets in the way.
@MainActor
final class BadgeOverlay {
  private struct Content: Equatable {
    let chat: ChatID
    let mode: ProtectionMode
  }

  private let panel = OverlayPanel.make(interactive: false)
  private var content: Content?

  func show(chat: ChatID, mode: ProtectionMode, above composerFrame: CGRect) {
    let next = Content(chat: chat, mode: mode)
    if next != content {
      content = next
      let host = NSHostingView(
        rootView: GuardBadge(chatName: chat.name.value, mode: mode).padding(8))
      panel.contentView = host
      panel.setContentSize(host.fittingSize)
    }

    // Sit just above the composer, aligned with its leading side
    // (the 8pt padding around the badge gives its shadow room).
    let composer = composerFrame.flippedToAppKit
    panel.setFrameOrigin(
      CGPoint(x: composer.minX - 8, y: composer.maxY - 2 + Self.gap(above: chat.messenger)))
    if !panel.isVisible { panel.orderFrontRegardless() }
  }

  /// Extra room between the badge and the message box. WhatsApp reports its box flush with
  /// the visible field, Slack a box with its own margin; this evens out how far the badge
  /// floats above each.
  private static func gap(above messenger: Messenger) -> CGFloat {
    switch messenger {
    case .whatsApp: 7
    case .slack: 0
    }
  }

  func hide() {
    guard panel.isVisible else { return }
    panel.orderOut(nil)
    content = nil
  }
}
