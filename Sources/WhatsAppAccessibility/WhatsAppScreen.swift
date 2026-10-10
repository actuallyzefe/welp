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
  /// The chat last named in the chat header. The media preview hides the header and opens
  /// over this chat.
  private var headerChat: ChatID?
  /// How the open media preview's recipient chip named `headerChat` when Welp first saw it.
  private var previewRecipient: ChatName?

  /// - Parameter postReturnKey: Posts a Return key press the interceptor lets through.
  public init(postReturnKey: @escaping @MainActor () -> Void) {
    self.postReturnKey = postReturnKey
    AXElement.limitMessagingTimeout(to: Self.messagingTimeout)
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
      messenger: messenger, chat: chat(in: window, watching: true),
      composerFrame: (composer(in: window) ?? captionField(in: window))?.frame)
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
    guard let app = runningApp, app.receivesKeys(routedTo: targetProcess) else { return nil }
    let root = applicationElement(app)

    // Right after an app switch WhatsApp may be too busy to say what has focus. Return still
    // reaches it, so assume the worst rather than let it through.
    guard let focused = root.focusedElement, focused.role != nil else {
      return unknownReturnKeyTarget(in: app)
    }
    guard isMessageInput(focused) else {
      return mediaPreviewReturnKeyTarget(in: focused.window ?? root.mainWindow, app: app)
    }

    let input = focused
    let window = input.window
    let chat = window.flatMap { self.chat(in: $0) }
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
        guard window.flatMap({ self.chat(in: $0) }) == chat else { return .targetChanged }
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

  /// Return while focus is unreadable: the chat is unknown and there is nothing to compare.
  private func unknownReturnKeyTarget(in app: NSRunningApplication) -> SendTarget {
    let context = SendContext(
      messenger: messenger, trigger: .returnKey, chat: nil, text: "", isEmpty: false)
    return SendTarget(
      context: context,
      // Explicitly approved by the user; there is nothing to compare against.
      replay: { [weak self] in
        self?.replayReturnKey()
        return .sent
      },
      restoreFocus: { app.activate() }
    )
  }

  /// Return in the media preview while its caption box doesn't have focus, as right after an
  /// image is pasted. Whether WhatsApp sends then isn't known, so the send is held anyway:
  /// an extra question is better than a photo sent unchecked.
  private func mediaPreviewReturnKeyTarget(in window: AXElement?, app: NSRunningApplication)
    -> SendTarget?
  {
    guard let window, mediaSendButton(in: window) != nil else { return nil }
    let chat = chat(in: window)
    let context = SendContext(
      messenger: messenger, trigger: .returnKey, chat: chat, text: "", isEmpty: false)
    return SendTarget(
      context: context,
      replay: { [weak self] in
        guard let self else { return .failed }
        guard self.chat(in: window) == chat, let button = mediaSendButton(in: window) else {
          return .targetChanged
        }
        return button.press() ? .sent : .failed
      },
      restoreFocus: { app.activate() }
    )
  }

  private func clickTarget(at point: CGPoint) -> SendTarget? {
    guard let app = runningApp,
      WindowOwnerLocator.ownerPID(at: point) == app.processIdentifier
    else { return nil }

    guard
      let button = AXElement.systemWide.element(at: point)?
        .selfOrAncestor(maxDepth: 4, where: isSendButton)
    else { return nil }

    let window = button.window
    let chat = window.flatMap { self.chat(in: $0) }
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
        guard window.flatMap({ self.chat(in: $0) }) == chat else { return .targetChanged }
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
        Open chat: \(window.flatMap { chat(in: $0) }?.description ?? "not detected")
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
    AXElement.application(app.processIdentifier)
  }

  /// - Parameter watching: `true` from the regular look at the screen, which may note how a
  ///   newly opened media preview names its chat; never from a send being decided.
  private func chat(in window: AXElement, watching: Bool = false) -> ChatID? {
    guard let title = window.firstDescendant(where: { $0.identifier == Ids.chatTitle }) else {
      return mediaPreviewChat(in: window, watching: watching)
    }
    headerChat = ChatName(title.label).map { ChatID(messenger: messenger, name: $0) }
    previewRecipient = nil
    return headerChat
  }

  /// The chat the media preview sends to. The preview opens over the chat in the header, but
  /// its recipient chip doesn't always use that chat's name (your own chat is "You"). So the
  /// chip's first name, seen within a moment of the preview opening and before any recipient
  /// can be changed, stands for the header chat. Several recipients or a changed one are an
  /// unknown chat, which is asked about.
  private func mediaPreviewChat(in window: AXElement, watching: Bool) -> ChatID? {
    guard let headerChat,
      let chip = window.firstDescendant(where: { $0.identifier == Ids.mediaRecipient }),
      let chips = chip.parent?.children.filter({ $0.identifier == Ids.mediaRecipient }),
      chips.count == 1, let recipient = ChatName(chip.label)
    else { return nil }
    if watching, previewRecipient == nil { previewRecipient = recipient }
    return recipient == headerChat.name || recipient == previewRecipient ? headerChat : nil
  }

  private func composer(in window: AXElement) -> AXElement? {
    window.firstDescendant { $0.identifier == Ids.composer }
  }

  private func mediaSendButton(in window: AXElement) -> AXElement? {
    window.firstDescendant { $0.identifier == Ids.mediaSendButton }
  }

  private func captionField(in window: AXElement) -> AXElement? {
    window.firstDescendant { $0.identifier == Ids.captionField }
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
