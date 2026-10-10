/// Every assumption about WhatsApp's UI lives here.
///
/// These are accessibility identifiers of the official macOS app (verified on 2.26.39.21).
/// They are locale-independent; labels are only used as fallbacks. If WhatsApp changes
/// its UI, this is the only file that should need an update. `Welp --diagnose` shows
/// what is currently visible.
enum WhatsAppIdentifiers {
  static let bundleID = "net.whatsapp.WhatsApp"

  /// Header button of the open conversation; its label is the chat's name.
  static let chatTitle = "NavigationBar_HeaderViewButton"
  /// A recipient of the media preview. The preview is modal and hides the header; the chip's
  /// label is usually the chat's name, but not always (your own chat is "You").
  static let mediaRecipient = "WAMultiSendBottomBarView_AudienceSelector_ContactChip"
  /// Caption box of the media preview, where the badge goes while the preview is open.
  static let captionField = "CaptionBar_TextView"
  /// The main message box.
  static let composer = "ChatBar_ComposerTextView"
  /// Send button next to the main message box.
  static let sendButton = "ChatBar_SendButton"
  /// Send button of the media preview.
  static let mediaSendButton = "WAMultiSendBottomBarView_SendButton"
  /// Chat list search field; Return there never sends a message.
  static let searchField = "TokenizedSearchBar_TextView"

  /// Fallback for send buttons without a known identifier (e.g. older media previews).
  static let sendButtonLabels: Set<String> = ["send", "gönder"]
}
