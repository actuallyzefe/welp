/// Every assumption about Slack's UI lives here.
///
/// Slack is an Electron app: its UI is a web page, exposed to the Accessibility API only
/// after `AXManualAccessibility` is switched on. Elements are recognised by their CSS
/// classes, which do not depend on the UI language. Verified on Slack 4.52.171.
enum SlackIdentifiers {
  static let bundleID = "com.tinyspeck.slackmacgap"
  /// Electron's switch for exposing web content to assistive apps.
  static let manualAccessibilityAttribute = "AXManualAccessibility"

  /// The rich-text message box (Quill editor).
  static let composerClass = "ql-editor"
  /// Send button inside a message box.
  static let sendButtonClass = "c-wysiwyg_container__button--send"
  /// Present on the send button while there is nothing to send.
  static let disabledClass = "c-button--disabled"
  /// Message boxes that post messages: the channel footer and the thread footer.
  /// Other editors (e.g. editing an existing message) are deliberately not included.
  static let inputContainerClasses: Set<String> = [
    "p-workspace__input", "p-threads_footer__input",
  ]
  /// The message box that replies to a thread.
  static let threadInputContainerClass = "p-threads_footer__input"
  /// A view: the conversation or thread shown in the middle, or the panel beside it.
  static let viewContentsClass = "p-view_contents"
  /// Link to the thread's conversation in the header of a thread shown on its own (from
  /// Activity). Its description is the conversation's name as in the window title. A thread
  /// in the panel beside its conversation has no such link.
  static let threadConversationLinkClass = "p-threads_flexpane__header_permalink"
}
