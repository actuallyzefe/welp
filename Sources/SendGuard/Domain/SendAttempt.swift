import SharedKernel

public enum SendTrigger: Sendable, Equatable {
  case returnKey
  case sendButton
}

/// A send the user started, captured before it reaches the messenger.
public struct SendAttempt: Sendable, Equatable {
  public static let previewMaxLength = 280

  public let messenger: Messenger
  /// `nil` when the target chat could not be determined.
  public let chat: ChatID?
  /// Shortened message text; empty for attachment-only sends.
  public let preview: String
  public let trigger: SendTrigger

  public init(messenger: Messenger, chat: ChatID?, text: String, trigger: SendTrigger) {
    self.messenger = messenger
    self.chat = chat
    self.preview = Self.makePreview(text)
    self.trigger = trigger
  }

  /// Whether `context` sends this same message to the same chat again, by either gesture.
  public func isRepeated(by context: SendContext) -> Bool {
    context.messenger == messenger && context.chat == chat
      && Self.makePreview(context.text) == preview
  }

  private static func makePreview(_ text: String) -> String {
    let compact = TextNormalizer.normalize(text)
    guard compact.count > previewMaxLength else { return compact }
    let head = compact.prefix(previewMaxLength - 1).trimmingCharacters(in: .whitespaces)
    return head + "…"
  }
}
