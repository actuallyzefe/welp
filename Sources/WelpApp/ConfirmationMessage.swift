import Foundation
import SendGuard

/// Texts shown in the "Are you sure?" prompt.
struct ConfirmationMessage: Equatable {
  let title: String
  /// The prompt's one-line question: "Send to Acme?", or where it goes when the chat is unknown.
  let headline: String
  /// Where the message goes: the guarded chat, or that it couldn't be told.
  let target: String
  /// The message itself, or a stand-in for attachment-only sends.
  let content: String
  /// `target` and `content` together, for plain-text surfaces.
  var detail: String { "\(target)\n\n\(content)" }
  let confirmLabel: String
  let cancelLabel: String

  init(for attempt: SendAttempt) {
    target =
      if let chat = attempt.chat {
        String(
          localized: "This message will go to a guarded chat:\n\(chat.description)",
          bundle: .localization,
          comment: "Confirmation prompt. The argument is the chat, e.g. “Slack › Acme › general”.")
      } else {
        String(
          localized:
            "\(attempt.messenger.displayName): couldn’t tell which chat this message will go to.",
          bundle: .localization,
          comment:
            "Confirmation prompt when the chat is unknown. The argument is WhatsApp or Slack.")
      }
    content =
      attempt.preview.isEmpty
      ? String(
        localized: "Attachment / media",
        bundle: .localization,
        comment: "Confirmation prompt: shown instead of the text when sending only a file.")
      : attempt.preview

    title = String(
      localized: "Are you sure?", bundle: .localization,
      comment: "Title of the prompt shown before sending to a guarded chat.")
    headline =
      if let chat = attempt.chat {
        String(
          localized: "Send to \(chat.name.value)?", bundle: .localization,
          comment:
            "Question in the prompt before sending to a guarded chat. The argument is the chat name."
        )
      } else {
        target
      }
    confirmLabel = String(
      localized: "Send", bundle: .localization, comment: "Confirmation prompt button.")
    cancelLabel = String(
      localized: "Cancel", bundle: .localization,
      comment: "Confirmation prompt button; the default, so a reflexive Return cancels.")
  }
}

extension SendNotice {
  /// The text of the notice toast.
  var message: String {
    switch self {
    case .targetChanged(let attempt):
      String(
        localized:
          "Message not sent: you left the chat or edited the message. It’s still in the message box of \(attempt.destination).",
        bundle: .localization,
        comment:
          "Toast after a held message was dropped for safety. The argument is a chat name, or WhatsApp / Slack."
      )
    case .sendFailed:
      String(
        localized: "Couldn’t send the message. Please try again.", bundle: .localization,
        comment: "Toast after a held message could not be sent.")
    }
  }
}

extension SendAttempt {
  /// Where the message goes, for short texts: the chat's name, or the messenger's.
  var destination: String { chat?.name.value ?? messenger.displayName }
}
