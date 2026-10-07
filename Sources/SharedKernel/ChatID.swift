/// Identifies a conversation across messengers: app + workspace (Slack only) + name.
///
/// Equality follows `ChatName`, so it is case-insensitive and ignores invisible characters.
public struct ChatID: Hashable, Sendable, CustomStringConvertible {
  public let messenger: Messenger
  /// The Slack workspace; `nil` for messengers without workspaces.
  public let workspace: ChatName?
  public let name: ChatName

  public init(messenger: Messenger, workspace: ChatName? = nil, name: ChatName) {
    self.messenger = messenger
    self.workspace = workspace
    self.name = name
  }

  /// e.g. "Slack › Sentez App Studio › test" or "WhatsApp › 2T1K".
  public var description: String {
    ([messenger.displayName, workspace?.value, name.value] as [String?])
      .compactMap { $0 }
      .joined(separator: " › ")
  }
}
