#if DEBUG
  import AppKit
  import GuardedChats
  import Preferences
  import SendGuard
  import SharedKernel
  import SwiftUI

  /// Debug-only: renders every settings pane with sample data to PNG files, in light and
  /// dark mode, so the design can be reviewed without touching real data.
  /// Usage: `Welp --render-settings <output-directory>`
  @MainActor
  enum SettingsSnapshots {
    static func render(to directory: URL) throws {
      Theme.usesGlass = false
      let model = try sampleModel()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

      for pane in SettingsModel.Pane.allCases {
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
          model.pane = pane
          let url = directory.appendingPathComponent("\(pane.rawValue)-\(suffix).png")
          try snapshot(SettingsView(model: model), appearance: appearance, to: url)
        }
      }
      let badge = GuardBadge(chatName: .sampleChatName, mode: .firstMessage).padding(20)
      try snapshot(badge, appearance: .aqua, to: directory.appendingPathComponent("badge.png"))
      try snapshot(
        badge, appearance: .darkAqua, to: directory.appendingPathComponent("badge-dark.png"))
      try renderSendPrompts(to: directory)
    }

    /// The cards shown above the message box while a send is held.
    private static func renderSendPrompts(to directory: URL) throws {
      let attempt = SendAttempt(
        messenger: .whatsApp,
        chat: ChatID(messenger: .whatsApp, name: ChatName(.sampleChatName)!),
        text: String(
          localized: "The offer is attached, let me know what you think.",
          bundle: .localization, comment: "Made-up message shown in screenshots of the prompts."),
        trigger: .returnKey)
      let cards: [(String, AnyView)] = [
        ("prompt-confirm", AnyView(ConfirmationCard(attempt: attempt) { _ in })),
        (
          "prompt-undo",
          AnyView(UndoCard(attempt: attempt, seconds: 5, onUndo: {}, onSendNow: {}))
        ),
        (
          "prompt-notice",
          AnyView(NoticeCard(notice: .targetChanged(attempt), returnAndSend: {}))
        ),
      ]
      for (name, card) in cards {
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
          try snapshot(
            card, appearance: appearance,
            to: directory.appendingPathComponent("\(name)-\(suffix).png"))
        }
      }
    }

    private static func sampleModel() throws -> SettingsModel {
      let temp = FileManager.default.temporaryDirectory
        .appendingPathComponent("welp-snapshots-\(UUID().uuidString)")
      let chats = GuardedChatsService(
        repository: JSONFileGuardedChatRepository(
          fileURL: temp.appendingPathComponent("chats.json"), logger: NullLogger()))
      let customer = ChatID(messenger: .whatsApp, name: ChatName(.sampleChatName)!)
      let board = ChatID(
        messenger: .slack, workspace: ChatName("Acme Studio"),
        name: ChatName(
          String(
            localized: "board", bundle: .localization,
            comment: "Made-up Slack channel name for screenshots; lowercase, no spaces."))!)
      let sales = ChatID(
        messenger: .slack, workspace: ChatName("Acme Studio"),
        name: ChatName(
          String(
            localized: "sales", bundle: .localization,
            comment: "Made-up Slack channel name for screenshots; lowercase, no spaces."))!)
      try chats.protect(customer, mode: .firstMessage)
      try chats.protect(board, mode: .everyMessage)
      try chats.protect(sales, mode: .undo)
      try chats.setPaused(true, for: sales)

      let defaultsName = "welp-snapshots-\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: defaultsName)!
      let preferences = PreferencesService(
        store: UserDefaultsPreferencesStore(defaults: defaults, logger: NullLogger()))

      let screens: [any MessengerScreen] = [
        SampleScreen(chat: customer),
        SampleScreen(
          chat: ChatID(
            messenger: .slack, workspace: ChatName("Acme Studio"),
            name: ChatName(
              String(
                localized: "general", bundle: .localization,
                comment: "Made-up Slack channel name for screenshots; lowercase, no spaces."))!)),
      ]
      let model = SettingsModel(
        guardedChats: chats, preferences: preferences,
        edition: SnapshotEdition(), screens: screens,
        permission: GrantedPermission(),
        language: LanguageSetting(defaults: defaults, domain: defaultsName),
        protectionStatus: { true })
      model.startRefreshing()
      model.stopRefreshing()
      return model
    }

    private static func snapshot<V: View>(
      _ view: V, appearance: NSAppearance.Name, to url: URL
    ) throws {
      // `cacheDisplay` skips the window background, so paint it into the view itself.
      let host = NSHostingView(
        rootView: view.background(Color(nsColor: .windowBackgroundColor)))
      host.appearance = NSAppearance(named: appearance)
      let size = host.fittingSize.width > 200 ? CGSize(width: 880, height: 640) : host.fittingSize
      let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless],
        backing: .buffered, defer: false)
      window.appearance = NSAppearance(named: appearance)
      window.backgroundColor =
        appearance == .darkAqua
        ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.99, alpha: 1)
      window.contentView = host
      host.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date().addingTimeInterval(0.3))

      guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
  }

  /// Screenshots show every sample chat protected, whatever the edition's plan.
  private final class SnapshotEdition: WelpEdition {
    func makeScreens(postReturnKey: @escaping @MainActor (_ withCommand: Bool) -> Void)
      -> [any MessengerScreen]
    { [] }
    func isAvailable(_ messenger: Messenger) -> Bool { true }
    func requestAccess(to messenger: Messenger, openPlan: @escaping @MainActor () -> Void) {}
    func planSection() -> AnyView? { nil }
    var updater: (any AppUpdater)? { nil }
  }

  /// Screenshots show the normal state, whatever the permission of the debug binary.
  private final class GrantedPermission: AccessibilityPermission {
    override var isGranted: Bool { true }
  }

  @MainActor
  private final class SampleScreen: MessengerScreen {
    let chat: ChatID
    init(chat: ChatID) { self.chat = chat }

    var messenger: Messenger { chat.messenger }
    var bundleIdentifier: String { "sample.\(chat.messenger.rawValue)" }
    var isRunning: Bool { true }
    func activeChat() -> ChatID? { chat }
    func conversationSnapshot() -> ConversationSnapshot? {
      ConversationSnapshot(messenger: messenger, chat: chat, composerFrame: nil)
    }
    func diagnosticReport() -> String { "" }
    func sendTarget(for gesture: SendGesture) -> SendTarget? { nil }
  }
#endif
