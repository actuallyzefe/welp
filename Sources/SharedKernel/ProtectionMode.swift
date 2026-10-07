/// How a guarded chat is protected.
public enum ProtectionMode: String, Codable, Sendable, CaseIterable {
  /// Ask before every message. For very sensitive chats.
  case everyMessage
  /// Ask before the first message after entering the chat; stay quiet while you remain there.
  case firstMessage
  /// Don't ask: hold the message for a few seconds with an "Undo" notice, then send.
  case undo

  public static let `default` = ProtectionMode.firstMessage
}
