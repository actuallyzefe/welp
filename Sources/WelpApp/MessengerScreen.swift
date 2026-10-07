import SendGuard
import SharedKernel
import WhatsAppAccessibility

/// What the app layer needs from each messenger adapter, beyond guarding sends.
@MainActor
public protocol MessengerScreen: SendTargetScreen {
  var messenger: Messenger { get }
  var bundleIdentifier: String { get }
  var isRunning: Bool { get }
  func activeChat() -> ChatID?
  func conversationSnapshot() -> ConversationSnapshot?
  func diagnosticReport() -> String
}

extension WhatsAppScreen: MessengerScreen {}
