/// Parses Slack's window title, e.g. `test (Channel) - Sentez App Studio - 5 new items - Slack`.
///
/// Conversations always carry their kind in parentheses ("(Channel)", "(DM)", "(Kanal)"…).
/// Titles without it (Threads, Activity, Later…) are not a single conversation: they yield
/// only the workspace, and `conversation` is `nil`.
struct SlackWindowTitle: Equatable {
  let conversation: String?
  let workspace: String

  private static let separator = " - "
  private static let appName = "Slack"

  init?(_ title: String) {
    let parts = title.components(separatedBy: Self.separator)
    guard parts.count >= 3, parts.last == Self.appName, let head = parts.first else {
      return nil
    }
    let workspace = parts[1].trimmingCharacters(in: .whitespaces)
    guard !workspace.isEmpty else { return nil }
    self.workspace = workspace

    guard head.hasSuffix(")"), let kindStart = head.lastIndex(of: "(") else {
      conversation = nil
      return
    }
    let conversation = head[..<kindStart].trimmingCharacters(in: .whitespaces)
    self.conversation = conversation.isEmpty ? nil : conversation
  }
}
