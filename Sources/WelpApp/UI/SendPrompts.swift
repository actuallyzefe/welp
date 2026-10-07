import SendGuard
import SharedKernel
import SwiftUI

/// The cards shown right above a guarded chat's message box while a send is held: the
/// "Are you sure?" prompt, the "Undo" countdown and short notices. One slim look for all
/// three, matching the composer badge: a glass card with the app's logo and Welp's mark.
enum SendPromptLayout {
  /// Transparent room around the card for its shadow; the panel is this much larger.
  static let inset: CGFloat = 14
  static let width: CGFloat = 320
}

private struct PromptCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) { content }
      .padding(12)
      .frame(width: SendPromptLayout.width, alignment: .leading)
      .glassSurface(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
      .padding(SendPromptLayout.inset)
  }
}

/// The app's logo and one line, with Welp's mark on the right.
private struct PromptHeader: View {
  let messenger: Messenger
  let title: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(nsImage: .appGlyph(messenger.glyph, size: 13))
        .renderingMode(.template)
        .foregroundStyle(.secondary)
        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 6)
      WelpMark()
        .frame(height: 11)
        .foregroundStyle(Theme.signal)
        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
    }
  }
}

/// The held message, in the secondary color under the header.
private struct MessagePreview: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .lineLimit(3)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 21)  // Under the title, past the logo.
  }
}

/// A button title with its key, e.g. "Send ↩".
private struct ShortcutLabel: View {
  let title: String
  let key: String

  var body: some View {
    HStack(spacing: 5) {
      Text(title)
      Text(verbatim: key).opacity(0.55)
    }
  }
}

// MARK: Are you sure?

/// Return sends: the prompt itself is the pause, so the second Return is a decision. Escape
/// or "Cancel" stops the message. (The panel ignores a Return that comes too fast to have
/// been one; see `ComposerConfirmationPrompt`.)
struct ConfirmationCard: View {
  let attempt: SendAttempt
  let decide: (_ send: Bool) -> Void

  var body: some View {
    let message = ConfirmationMessage(for: attempt)
    PromptCard {
      PromptHeader(messenger: attempt.messenger, title: message.headline)
      MessagePreview(text: message.content)
      HStack(spacing: 6) {
        Spacer()
        Button {
          decide(false)
        } label: {
          ShortcutLabel(title: message.cancelLabel, key: "esc")
        }
        .keyboardShortcut(.cancelAction)
        Button {
          decide(true)
        } label: {
          ShortcutLabel(title: message.confirmLabel, key: "↩")
        }
        .primaryButtonStyle(tint: attempt.messenger.brandColor, compact: true)
        .keyboardShortcut(.defaultAction)
      }
      .padding(.top, 2)
    }
  }
}

// MARK: Undo

// The Undo and notice cards never take the keyboard, so the system's glass button would draw
// as inactive (washed out) there; their call to action uses the solid style instead.

struct UndoCard: View {
  let attempt: SendAttempt
  let seconds: TimeInterval
  let onUndo: () -> Void
  let onSendNow: () -> Void
  @State private var remaining: CGFloat = 1

  var body: some View {
    PromptCard {
      PromptHeader(
        messenger: attempt.messenger,
        title: String(
          localized: "Sending to \(attempt.destination)…", bundle: .localization,
          comment: "Undo toast. The argument is a chat name, or WhatsApp / Slack."))
      if !attempt.preview.isEmpty {
        MessagePreview(text: attempt.preview)
      }
      HStack(spacing: 8) {
        // How long until it goes out.
        GeometryReader { proxy in
          Capsule().fill(Theme.raisedSurface)
            .overlay(alignment: .leading) {
              Capsule().fill(Theme.secondaryText).frame(width: proxy.size.width * remaining)
            }
        }
        .frame(height: 3)
        .padding(.leading, 21)
        // The message goes anyway; the card is there to stop it, so Undo is the main button.
        // Return in the message box sends now and Escape undoes (the card never takes the
        // keyboard; the input interceptor handles both).
        Button(action: onSendNow) {
          ShortcutLabel(
            title: String(
              localized: "Send now", bundle: .localization,
              comment: "Undo toast button; sends the held message without waiting."),
            key: "↩")
        }
        Button(action: onUndo) {
          ShortcutLabel(
            title: String(
              localized: "Undo", bundle: .localization,
              comment: "Undo toast button; stops the held message."),
            key: "esc")
        }
        .buttonStyle(PrimaryButtonStyle(tint: attempt.messenger.brandColor, compact: true))
      }
      .padding(.top, 2)
    }
    .onAppear {
      withAnimation(.linear(duration: seconds)) { remaining = 0 }
    }
  }
}

// MARK: Notices

struct NoticeCard: View {
  let notice: SendNotice
  let returnAndSend: (() -> Void)?

  var body: some View {
    PromptCard {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 13))
          .foregroundStyle(Theme.signal)
        Text(notice.message)
          .font(.system(size: 12.5))
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
        WelpMark()
          .frame(height: 11)
          .foregroundStyle(Theme.signal)
          .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
      }
      if let returnAndSend {
        HStack {
          Spacer()
          Button(
            String(
              localized: "Return and send", bundle: .localization,
              comment:
                "Notice button: opens the chat the held message was written in and sends it there."
            ), action: returnAndSend
          )
          .buttonStyle(
            PrimaryButtonStyle(tint: notice.messenger?.brandColor ?? Theme.brand, compact: true))
        }
      }
    }
  }
}

extension SendNotice {
  /// The app the notice is about, when it is known.
  fileprivate var messenger: Messenger? {
    switch self {
    case .targetChanged(let attempt): attempt.messenger
    case .sendFailed: nil
    }
  }
}
