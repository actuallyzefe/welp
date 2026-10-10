import AccessibilitySupport
import AppKit
import SendGuard
import SharedKernel

/// Reads the Slack desktop app through the Accessibility API.
@MainActor
public final class SlackScreen: SendTargetScreen {
  private typealias Ids = SlackIdentifiers

  public let messenger = Messenger.slack
  public let bundleIdentifier = SlackIdentifiers.bundleID

  private static let messagingTimeout: Float = 0.25
  private static let launchRetryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(15)]
  /// How long a return to a conversation may take: 30 × 100 ms.
  private static let reopenPolls = 30
  private static let reopenPollInterval: Duration = .milliseconds(100)

  private let postReturnKey: @MainActor (_ withCommand: Bool) -> Void
  /// The Slack process whose web content we already exposed.
  private var exposedProcess: pid_t?
  private var launchObserver: (any NSObjectProtocol)?

  /// - Parameter postReturnKey: Posts a Return key press the interceptor lets through.
  public init(postReturnKey: @escaping @MainActor (_ withCommand: Bool) -> Void) {
    self.postReturnKey = postReturnKey
    AXElement.limitMessagingTimeout(to: Self.messagingTimeout)
    observeLaunches()
    exposeWebContent()
  }

  public var isRunning: Bool { runningApp != nil }

  /// The conversation open in Slack's main window, if any.
  public func activeChat() -> ChatID? {
    conversationSnapshot()?.chat
  }

  /// The open conversation and, while you type in it, where the message box is on screen.
  ///
  /// `nil` while Slack shows no single conversation (Activity, Threads…) and you are not
  /// replying to a thread there: nothing is open to enter or leave, so an approval given in
  /// a thread survives a look at the list it came from.
  public func conversationSnapshot() -> ConversationSnapshot? {
    guard let app = runningApp else { return nil }
    let root = applicationElement(app)
    guard let window = root.mainWindow else { return nil }
    // Slack's tree is large; only the focused box is located, not searched for.
    let box = root.focusedElement.flatMap(messageBox(focused:))
    guard let chat = chat(of: box?.container, in: window) else { return nil }
    // The whole message box, toolbars included: the text area alone sits below Slack's
    // formatting bar, and anything placed on its top edge would cover that bar.
    return ConversationSnapshot(
      messenger: messenger, chat: chat, composerFrame: (box?.container ?? box?.composer)?.frame)
  }

  // MARK: SendTargetScreen

  public func sendTarget(for gesture: SendGesture) -> SendTarget? {
    switch gesture {
    case .returnKey(let withCommand, let targetProcess):
      returnKeyTarget(withCommand: withCommand, to: targetProcess)
    case .click(let point): clickTarget(at: point)
    }
  }

  private func returnKeyTarget(withCommand: Bool, to targetProcess: pid_t) -> SendTarget? {
    guard let app = runningApp, app.receivesKeys(routedTo: targetProcess) else { return nil }
    let root = applicationElement(app)

    guard let focused = root.focusedElement, focused.role != nil else {
      // Web content not exposed (yet), or Slack too busy to answer, e.g. while it rebuilds its
      // web content after an app switch: we cannot see where Return goes, so assume the worst.
      let context = SendContext(
        messenger: messenger, trigger: .returnKey, chat: nil, text: "", isEmpty: false)
      // Explicitly approved by the user; there is nothing to compare against.
      return target(context, app: app) { [weak self] in
        self?.replayReturnKey(withCommand: withCommand, in: app)
        return .sent
      }
    }

    guard let held = messageBox(focused: focused) else { return nil }

    let window = focused.window ?? root.mainWindow
    let chat = window.flatMap { self.chat(of: held.container, in: $0) }
    let text = focused.value ?? ""
    let sendButton = sendButton(in: held.container)
    let context = SendContext(
      messenger: messenger,
      trigger: .returnKey,
      chat: chat,
      text: text,
      isEmpty: sendButton.map { $0.hasClass(Ids.disabledClass) } ?? text.allSatisfy(\.isWhitespace)
    )
    let reopen = reopenChat(chat, box: held.container, window: window)
    return target(context, app: app, reopenChat: reopen) { [weak self] in
      guard let self else { return .failed }
      // Slack rebuilds its web content's accessibility nodes, so elements captured when the
      // send was held may be stale by now: reading them fails and pressing them does nothing.
      let current =
        applicationElement(app).focusedElement.flatMap(messageBox(focused:))
        ?? window.flatMap(messageBox(in:)) ?? held
      guard window.flatMap({ self.chat(of: current.container, in: $0) }) == chat,
        Self.isSameText(current.composer.value, text)
      else { return .targetChanged }
      if let button = self.sendButton(in: current.container), button.press() { return .sent }
      replayReturnKey(withCommand: withCommand, in: app)
      return .sent
    }
  }

  private func clickTarget(at point: CGPoint) -> SendTarget? {
    guard let app = runningApp,
      WindowOwnerLocator.ownerPID(at: point) == app.processIdentifier
    else { return nil }
    exposeWebContent()

    guard let held = sendButton(at: point) else { return nil }

    let window = held.button.window
    let chat = window.flatMap { self.chat(of: held.container, in: $0) }
    let text = held.composer?.value ?? ""
    let context = SendContext(
      messenger: messenger,
      trigger: .sendButton,
      chat: chat,
      text: text,
      isEmpty: held.button.hasClass(Ids.disabledClass)
    )
    let reopen = reopenChat(chat, box: held.container, window: window)
    return target(context, app: app, reopenChat: reopen) { [weak self] in
      guard let self else { return .failed }
      // Looked up again for the same reason as in `returnKeyTarget`. After a return to the
      // chat the button may have moved, so the message box's own button is the fallback.
      let current =
        sendButton(at: point)
        ?? window.flatMap(messageBox(in:)).flatMap { box in
          self.sendButton(in: box.container).map { ($0, box.container, box.composer) }
        } ?? held
      guard window.flatMap({ self.chat(of: current.container, in: $0) }) == chat,
        Self.isSameText(current.composer?.value, text)
      else { return .targetChanged }
      return current.button.press() ? .sent : .failed
    }
  }

  /// The message box `focused` belongs to, if it is one that posts messages.
  private func messageBox(focused: AXElement) -> (composer: AXElement, container: AXElement)? {
    guard isComposer(focused),
      let container = focused.selfOrAncestor(maxDepth: 8, where: isInputContainer)
    else { return nil }
    return (focused, container)
  }

  /// The first message box in the window, wherever focus is. Replays still check its text.
  /// Never searched for inside the event tap, so it may take a little longer.
  private func messageBox(in window: AXElement) -> (composer: AXElement, container: AXElement)? {
    window.firstDescendant(maxNodes: 5_000, within: .milliseconds(500)) { isComposer($0) }
      .flatMap(messageBox(focused:))
  }

  /// The send button under `point` and the message box it sends.
  private func sendButton(at point: CGPoint)
    -> (button: AXElement, container: AXElement?, composer: AXElement?)?
  {
    guard
      let button = AXElement.systemWide.element(at: point)?
        .selfOrAncestor(maxDepth: 4, where: { $0.hasClass(Ids.sendButtonClass) })
    else { return nil }
    let container = button.selfOrAncestor(maxDepth: 8, where: isInputContainer)
    let composer = container?
      .firstDescendant(maxNodes: 300) { $0.hasClass(Ids.composerClass) }
    return (button, container, composer)
  }

  /// Compares what is visible, not how Slack's web content happens to encode it.
  private static func isSameText(_ current: String?, _ held: String) -> Bool {
    TextNormalizer.normalize(current ?? "") == TextNormalizer.normalize(held)
  }

  private func target(
    _ context: SendContext, app: NSRunningApplication,
    reopenChat: SendTarget.ReopenChat? = nil,
    replay: @escaping @MainActor () -> ReplayResult
  ) -> SendTarget {
    SendTarget(
      context: context, replay: replay, restoreFocus: { app.activate() }, reopenChat: reopenChat)
  }

  /// Opens the conversation through Slack's own link, then waits until the window shows it
  /// and its message box has loaded. `nil` when the conversation's link is unknown, and for
  /// thread replies: the link opens the conversation, not the thread.
  private func reopenChat(_ chat: ChatID?, box: AXElement?, window: AXElement?)
    -> SendTarget.ReopenChat?
  {
    guard let chat, let window, box.map(isThreadInput) != true,
      let link = channelLink(in: window)
    else { return nil }
    return { [weak self] completion in
      guard NSWorkspace.shared.open(link) else { return completion(false) }
      Task { @MainActor in
        for _ in 0..<Self.reopenPolls {
          try? await Task.sleep(for: Self.reopenPollInterval)
          guard let self else { return completion(false) }
          if self.chat(in: window) == chat, self.messageBox(in: window) != nil {
            return completion(true)
          }
        }
        completion(false)
      }
    }
  }

  /// A `slack://` link to the conversation the window shows, built from the page address
  /// (`https://app.slack.com/client/<team>/<conversation>…`).
  private func channelLink(in window: AXElement) -> URL? {
    guard let address = webArea(in: window)?.url else { return nil }
    let parts = address.pathComponents
    guard let client = parts.firstIndex(of: "client"), parts.count > client + 2 else {
      return nil
    }
    var link = URLComponents()
    link.scheme = "slack"
    link.host = "channel"
    link.queryItems = [
      URLQueryItem(name: "team", value: parts[client + 1]),
      URLQueryItem(name: "id", value: parts[client + 2]),
    ]
    return link.url
  }

  // MARK: Diagnostics

  /// Human-readable snapshot of what Welp can see; used by `Welp --diagnose`.
  public func diagnosticReport() -> String {
    guard let app = runningApp else { return "Slack is not running." }
    let root = applicationElement(app)
    let window = root.mainWindow
    let focused = root.focusedElement
    let composer = window?.firstDescendant(maxNodes: 5_000, within: .seconds(2)) {
      $0.hasClass(Ids.composerClass)
        && $0.selfOrAncestor(maxDepth: 8, where: isInputContainer) != nil
    }
    let container = composer?.selfOrAncestor(maxDepth: 8, where: isInputContainer)
    let focusedBox = focused.flatMap(messageBox(focused:))
    return """
      Slack (pid \(app.processIdentifier), frontmost: \(app.isActive ? "yes" : "no"))
        Window title: \(window.flatMap(webArea(in:))?.title ?? "unreadable")
        Open chat: \(window.flatMap { chat(of: focusedBox?.container, in: $0) }?.description ?? "not detected")
        Message box: \(composer.map { "found, value=\"\($0.value ?? "")\"" } ?? "not found")
        Send button: \(container.flatMap(sendButton(in:)) == nil ? "not found" : "found")
        Focused element: \(focused.map { "\($0.role ?? "?") \($0.classList)" } ?? "none")
      """
  }

  // MARK: Slack UI model

  private var runningApp: NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: Ids.bundleID).first
  }

  private func applicationElement(_ app: NSRunningApplication) -> AXElement {
    exposeWebContent()
    return AXElement.application(app.processIdentifier)
  }

  private func webArea(in window: AXElement) -> AXElement? {
    window.firstDescendant(maxNodes: 100) { $0.role == "AXWebArea" }
  }

  /// The conversation the window shows.
  private func chat(in window: AXElement) -> ChatID? {
    chat(of: nil, in: window)
  }

  /// The conversation a message box posts to. A thread reply goes to the thread's
  /// conversation: the one named in the thread's header when the thread is shown on its own
  /// (Activity), otherwise the conversation the thread is shown beside.
  private func chat(of box: AXElement?, in window: AXElement) -> ChatID? {
    guard let title = webArea(in: window)?.title, let parsed = SlackWindowTitle(title)
    else { return nil }
    let thread = box.flatMap { isThreadInput($0) ? threadConversation(of: $0) : nil }
    guard let name = ChatName(thread ?? parsed.conversation) else { return nil }
    return ChatID(messenger: messenger, workspace: ChatName(parsed.workspace), name: name)
  }

  /// The conversation named in the header of the thread `box` replies to, if it has one.
  private func threadConversation(of box: AXElement) -> String? {
    box.selfOrAncestor(maxDepth: 8) { $0.hasClass(Ids.viewContentsClass) }?
      .firstDescendant(maxNodes: 50) { $0.hasClass(Ids.threadConversationLinkClass) }?
      .label
  }

  private func isThreadInput(_ container: AXElement) -> Bool {
    container.hasClass(Ids.threadInputContainerClass)
  }

  private func isComposer(_ element: AXElement) -> Bool {
    element.role == kAXTextAreaRole && element.hasClass(Ids.composerClass)
  }

  private func isInputContainer(_ element: AXElement) -> Bool {
    !Ids.inputContainerClasses.isDisjoint(with: element.classList)
  }

  private func sendButton(in container: AXElement) -> AXElement? {
    container.firstDescendant(maxNodes: 300) { $0.hasClass(Ids.sendButtonClass) }
  }

  private func replayReturnKey(withCommand: Bool, in app: NSRunningApplication) {
    app.activate()
    Task { @MainActor [postReturnKey] in
      try? await Task.sleep(for: .milliseconds(150))
      postReturnKey(withCommand)
    }
  }

  // MARK: Exposing Electron's web content

  /// Asks Slack's Chromium to publish its accessibility tree. Idempotent per process.
  private func exposeWebContent() {
    guard let app = runningApp, exposedProcess != app.processIdentifier else { return }
    let switched = AXElement.application(app.processIdentifier)
      .setFlag(Ids.manualAccessibilityAttribute, true)
    if switched { exposedProcess = app.processIdentifier }
  }

  private func observeLaunches() {
    launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
    ) { [weak self] notification in
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      guard app?.bundleIdentifier == Ids.bundleID else { return }
      MainActor.assumeIsolated { self?.exposeWebContentAfterLaunch() }
    }
  }

  /// A freshly launched Slack needs a moment before it accepts the switch.
  private func exposeWebContentAfterLaunch() {
    exposedProcess = nil
    Task { @MainActor [weak self] in
      for delay in Self.launchRetryDelays {
        try? await Task.sleep(for: delay)
        guard let self else { return }
        self.exposedProcess = nil
        self.exposeWebContent()
      }
    }
  }
}
