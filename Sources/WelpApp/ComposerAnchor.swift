import AppKit

/// Where the frontmost messenger's message box is, so the send prompt and the toasts can sit
/// right above it, where the person is already looking, instead of in a corner of the screen.
@MainActor
final class ComposerAnchor {
  /// Room left for the composer badge, which sits on the message box's top edge.
  private static let badgeClearance: CGFloat = 30
  private static let screenMargin: CGFloat = 16

  private let screens: [any MessengerScreen]

  init(screens: [any MessengerScreen]) {
    self.screens = screens
  }

  /// The frontmost messenger's message box in AppKit screen coordinates, if it can be found.
  var composerFrame: CGRect? {
    let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    return screens.first { $0.bundleIdentifier == frontmost }?
      .conversationSnapshot()?.composerFrame?.flippedToAppKit
  }

  /// The frame for a panel of `size` (including its transparent `inset` around the card, which
  /// gives the shadow room): above the message box and its badge, aligned with its leading
  /// edge. Without a message box, `fallback` decides.
  func frame(for size: CGSize, inset: CGFloat, fallback: Fallback) -> CGRect {
    guard let composer = composerFrame,
      let screen = NSScreen.screens.first(where: { $0.frame.intersects(composer) })
    else { return fallback.frame(for: size, inset: inset) }

    let visible = screen.visibleFrame
    var origin = CGPoint(
      x: composer.minX - inset,
      y: composer.maxY + Self.badgeClearance - inset)
    // Keep the card on screen, e.g. when the chat window is near an edge.
    origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
    origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
    return CGRect(origin: origin, size: size)
  }

  /// Where a panel goes when no message box is found.
  enum Fallback {
    /// Centered on the screen with the pointer, like an alert.
    case center
    /// The top-right corner of the screen with the pointer, like a notification.
    case topRight

    @MainActor
    func frame(for size: CGSize, inset: CGFloat) -> CGRect {
      let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? .main
      let visible = screen?.visibleFrame ?? .zero
      let origin =
        switch self {
        case .center:
          CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        case .topRight:
          CGPoint(
            x: visible.maxX - size.width - ComposerAnchor.screenMargin + inset,
            y: visible.maxY - size.height - ComposerAnchor.screenMargin + inset)
        }
      return CGRect(origin: origin, size: size)
    }
  }
}
