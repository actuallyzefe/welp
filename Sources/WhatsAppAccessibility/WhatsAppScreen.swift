import AccessibilitySupport
import AppKit
import SendGuard
import SharedKernel

/// Reads the official WhatsApp for Mac app through the Accessibility API.
@MainActor
public final class WhatsAppScreen: SendTargetScreen {
  private typealias Ids = WhatsAppIdentifiers

  public let messenger = Messenger.whatsApp
  public let bundleIdentifier = WhatsAppIdentifiers.bundleID

  /// Upper bound for a single accessibility call; keeps the event tap responsive.
  private static let messagingTimeout: Float = 0.25
  private static let textInputRoles: Set<String> = [kAXTextAreaRole, kAXTextFieldRole]

  private let postReturnKey: @MainActor () -> Void

  /// - Parameter postReturnKey: Posts a Return key press the interceptor lets through.
  public init(postReturnKey: @escaping @MainActor () -> Void) {
    self.postReturnKey = postReturnKey
  }

  public var isRunning: Bool { runningApp != nil }

  /// The chat open in WhatsApp's main window, if any.
  public func activeChat() -> ChatID? {
    conversationSnapshot()?.chat
  }

  /// The open chat and where its message box is on screen.
  public func conversationSnapshot() -> ConversationSnapshot? {
    guard let app = runningApp, let window = applicationElement(app).mainWindow else {
      return nil
    }
    return ConversationSnapshot(
      messenger: messenger, chat: chat(in: window), composerFrame: composer(in: window)?.frame)
  }

  // MARK: SendTargetScreen

  public func sendTarget(for gesture: SendGesture) -> SendTarget? {
    switch gesture {
    case .returnKey(withCommand: false, let targetProcess): returnKeyTarget(to: targetProcess)
    case .returnKey(withCommand: true, _): nil  // ⌘↩ does not send in WhatsApp.
    case .click(let point): clickTarget(at: point)
    }
  }

  private func returnKeyTarget(to targetProcess: pid_t) -> SendTarget? {
    guard let app = runningApp, app.receivesKeys(routedTo: targetProcess),
      let input = applicationElement(app).focusedElement, isMessageInput(input)
    else { return nil }

    let window = input.window
    let chat = window.flatMap(chat(in:))
    let text = input.value ?? ""
    let isMainComposer = input.identifier == Ids.composer
    let context = SendContext(
      messenger: messenger,
      trigger: .returnKey,
      chat: chat,
      text: text,
      // An empty media caption still sends the media, so only the main box can be "empty".
      isEmpty: isMainComposer && text.allSatisfy(\.isWhitespace)
    )
    return SendTarget(
      context: context,
      replay: { [weak self] in
        guard let self else { return .failed }
        guard window.flatMap(self.chat(in:)) == chat else { return .targetChanged }
        // The main composer has a stable send button; anything else gets its Return back.
        if isMainComposer {
          guard window.flatMap(composer(in:))?.value == text else { return .targetChanged }
          if let button = window.flatMap(mainSendButton(in:)), button.press() { return .sent }
        }
        replayReturnKey()
        return .sent
      },
      restoreFocus: { app.activate() }
    )
  }

  private func clickTarget(at point: CGPoint) -> SendTarget? {
    guard let app = runningApp,
      WindowOwnerLocator.ownerPID(at: point) == app.processIdentifier
    else { return nil }

    let systemWide = AXElement.systemWide
    systemWide.setMessagingTimeout(seconds: Self.messagingTimeout)
    guard
      let button = systemWide.element(at: point)?
        .selfOrAncestor(maxDepth: 4, where: isSendButton)
    else { return nil }

    let window = button.window
    let chat = window.flatMap(chat(in:))
    let isMainComposer = button.identifier == Ids.sendButton
    let context = SendContext(
      messenger: messenger,
      trigger: .sendButton,
      chat: chat,
      text: isMainComposer ? window.flatMap(composer(in:))?.value ?? "" : "",
      isEmpty: false
    )
    return SendTarget(
      context: context,
      replay: { [weak self] in
        guard let self else { return .failed }
        guard window.flatMap(self.chat(in:)) == chat else { return .targetChanged }
        return button.press() ? .sent : .failed
      },
      restoreFocus: { app.activate() }
    )
  }

  // MARK: Diagnostics

  /// Human-readable snapshot of what Welp can see; used by `Welp --diagnose`.
  public func diagnosticReport() -> String {
    guard let app = runningApp else { return "WhatsApp is not running." }
    let root = applicationElement(app)
    let window = root.mainWindow
    let focused = root.focusedElement
    let describe = { (element: AXElement?) -> String in
      guard let element else { return "none" }
      return
        "\(element.role ?? "?") id=\(element.identifier ?? "-") value=\"\(element.value ?? "")\""
    }
    let isInput = focused.map(isMessageInput) ?? false
    return """
      WhatsApp (pid \(app.processIdentifier), frontmost: \(app.isActive ? "yes" : "no"))
        Open chat: \(window.flatMap(chat(in:))?.description ?? "not detected")
        Mesaj kutusu: \(describe(window.flatMap(composer(in:))))
        Send button: \(window.flatMap(mainSendButton(in:)) == nil ? "not found" : "found")
        Focused element: \(describe(focused)) → message box: \(isInput ? "yes" : "no")
      """
  }

  // MARK: WhatsApp UI model

  private var runningApp: NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: Ids.bundleID).first
  }

  private func applicationElement(_ app: NSRunningApplication) -> AXElement {
    let element = AXElement.application(app.processIdentifier)
    element.setMessagingTimeout(seconds: Self.messagingTimeout)
    return element
  }

  private func chat(in window: AXElement) -> ChatID? {
    let title = window.firstDescendant { $0.identifier == Ids.chatTitle }
    return ChatName((title ?? mediaRecipient(in: window))?.label)
      .map { ChatID(messenger: messenger, name: $0) }
  }

  /// The media preview's recipient, when it has exactly one: with several, no single chat is
  /// the target, so the send is treated as going to an unknown chat.
  private func mediaRecipient(in window: AXElement) -> AXElement? {
    guard let recipient = window.firstDescendant(where: { $0.identifier == Ids.mediaRecipient }),
      let recipients = recipient.parent?.children.filter({ $0.identifier == Ids.mediaRecipient }),
      recipients.count == 1
    else { return nil }
    return recipient
  }

  private func composer(in window: AXElement) -> AXElement? {
    window.firstDescendant { $0.identifier == Ids.composer }
  }

  private func mainSendButton(in window: AXElement) -> AXElement? {
    window.firstDescendant { $0.identifier == Ids.sendButton }
  }

  private func isMessageInput(_ element: AXElement) -> Bool {
    guard let role = element.role, Self.textInputRoles.contains(role) else { return false }
    return element.identifier != Ids.searchField && element.subrole != kAXSearchFieldSubrole
  }

  private func isSendButton(_ element: AXElement) -> Bool {
    if element.identifier == Ids.sendButton || element.identifier == Ids.mediaSendButton {
      return true
    }
    guard element.role == kAXButtonRole, let label = element.label else { return false }
    let normalized = TextNormalizer.normalize(label).lowercased(with: Locale(identifier: "tr_TR"))
    return Ids.sendButtonLabels.contains(normalized)
  }

  private func replayReturnKey() {
    runningApp?.activate()
    // Give WhatsApp a moment to regain keyboard focus before the key arrives.
    Task { @MainActor [postReturnKey] in
      try? await Task.sleep(for: .milliseconds(150))
      postReturnKey()
    }
  }
}
