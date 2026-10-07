import SharedKernel

/// What a messenger screen knows about a send gesture at the moment it happens.
public struct SendContext: Sendable, Equatable {
  public let messenger: Messenger
  public let trigger: SendTrigger
  public let chat: ChatID?
  public let text: String
  /// `true` when the gesture would send nothing (empty box, disabled send button).
  public let isEmpty: Bool

  public init(
    messenger: Messenger, trigger: SendTrigger, chat: ChatID?, text: String, isEmpty: Bool
  ) {
    self.messenger = messenger
    self.trigger = trigger
    self.chat = chat
    self.text = text
    self.isEmpty = isEmpty
  }
}
