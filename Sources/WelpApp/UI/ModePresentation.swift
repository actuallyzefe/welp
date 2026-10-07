import SharedKernel
import SwiftUI

/// How protection modes are presented to people.
extension ProtectionMode {
  var title: String {
    switch self {
    case .everyMessage:
      String(
        localized: "Ask on every message", bundle: .localization, comment: "Protection mode name.")
    case .firstMessage:
      String(
        localized: "Ask on first message", bundle: .localization, comment: "Protection mode name.")
    case .undo:
      String(
        localized: "Undo", bundle: .localization,
        comment: "Protection mode name: no prompt, the message is held with an Undo notice.")
    }
  }

  var shortTitle: String {
    switch self {
    case .everyMessage:
      String(
        localized: "Every message", bundle: .localization,
        comment: "Short protection mode name, in a compact picker.")
    case .firstMessage:
      String(
        localized: "First message", bundle: .localization,
        comment: "Short protection mode name, in a compact picker.")
    case .undo:
      String(
        localized: "Undo", bundle: .localization,
        comment: "Short protection mode name, in a compact picker.")
    }
  }

  var explanation: String {
    switch self {
    case .everyMessage:
      String(
        localized: "Asks before every send. For very sensitive chats, like the board.",
        bundle: .localization, comment: "Explanation of the “Ask on every message” mode.")
    case .firstMessage:
      String(
        localized:
          "Asks before the first message after you enter the chat. Stays quiet while you remain there.",
        bundle: .localization, comment: "Explanation of the “Ask on first message” mode.")
    case .undo:
      String(
        localized:
          "Never asks. Holds the message for a few seconds with a chance to “Undo”. Keeps you in the flow.",
        bundle: .localization, comment: "Explanation of the “Undo” mode.")
    }
  }

  var symbol: String {
    switch self {
    case .everyMessage: "exclamationmark.shield.fill"
    case .firstMessage: "checkmark.shield.fill"
    case .undo: "arrow.uturn.backward.circle.fill"
    }
  }
}

extension Messenger {
  /// The app's own color, for the calls to action about its chats: protecting and unlocking
  /// them in the settings, and sending or undoing in the prompts above its message box.
  var brandColor: Color {
    switch self {
    case .whatsApp: Color(nsColor: NSColor(hex: 0x25D366))
    case .slack: Color(nsColor: NSColor(hex: 0x1DB5BE))
    }
  }

  /// The app's logo in `Resources/Glyphs`, for `NSImage.appGlyph`.
  var glyph: String {
    switch self {
    case .whatsApp: "whatsapp"
    case .slack: "slack"
    }
  }

  var symbol: String {
    switch self {
    case .whatsApp: "phone.bubble.fill"
    case .slack: "number"
    }
  }
}

extension ChatID {
  /// Secondary line under a chat's name, e.g. "Slack · Sentez App Studio".
  var subtitle: String {
    [messenger.displayName, workspace?.value].compactMap { $0 }.joined(separator: " · ")
  }
}
