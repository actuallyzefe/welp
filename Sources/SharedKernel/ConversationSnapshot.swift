import CoreGraphics

/// What is currently open in a messenger, as seen from outside.
public struct ConversationSnapshot: Sendable, Equatable {
  public let messenger: Messenger
  public let chat: ChatID?
  /// The message box on screen, in global top-left-origin coordinates.
  public let composerFrame: CGRect?

  public init(messenger: Messenger, chat: ChatID?, composerFrame: CGRect?) {
    self.messenger = messenger
    self.chat = chat
    self.composerFrame = composerFrame
  }
}
