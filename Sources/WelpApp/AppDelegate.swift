import AppKit
import GuardedChats
import InputInterception
import Preferences
import SendGuard
import WhatsAppAccessibility

/// Composition root: builds the modules, wires them together and owns their lifetime.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = OSLogLogger(category: "app")
  private let permission = AccessibilityPermission()
  private var interceptor: InputInterceptor?
  private var statusMenu: StatusMenuController?
  private var settingsWindow: SettingsWindowController?
  private var monitor: ConversationMonitor?
  private let edition: any WelpEdition

  init(edition: any WelpEdition) {
    self.edition = edition
  }

  /// WhatsApp from the core, then whatever the edition adds.
  static func makeScreens(edition: any WelpEdition) -> [any MessengerScreen] {
    [WhatsAppScreen(postReturnKey: { InputInterceptor.postReturnKey(withCommand: false) })]
      + edition.makeScreens(postReturnKey: InputInterceptor.postReturnKey(withCommand:))
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let preferences = PreferencesService(
      store: UserDefaultsPreferencesStore(logger: OSLogLogger(category: "preferences")))
    let edition = self.edition
    let guardedChats = GuardedChatsService(
      repository: JSONFileGuardedChatRepository(
        fileURL: AppPaths.guardedChatsFile,
        logger: OSLogLogger(category: "guarded-chats")
      ),
      isAvailable: { $0 == .whatsApp || edition.isAvailable($0) }
    )
    do {
      try guardedChats.load()
    } catch {
      logger.error("Could not load guarded chats: \(error)")
      ErrorPresenter.show(
        title: String(
          localized: "Couldn’t read the guarded chats", bundle: .localization,
          comment: "Error alert title at launch."),
        error: error)
    }

    let screens = Self.makeScreens(edition: edition)
    let memory = ApprovalMemory()
    let anchor = ComposerAnchor(screens: screens)
    let coordinator = SendGuardCoordinator(
      policy: SendGuardPolicy(
        lookup: GuardedChatsLookup(service: guardedChats),
        memory: memory,
        behavior: { preferences.current.guardBehavior }
      ),
      memory: memory,
      screen: CompositeSendTargetScreen(screens),
      prompt: ComposerConfirmationPrompt(anchor: anchor),
      feedback: ToastController(anchor: anchor),
      logger: OSLogLogger(category: "send-guard")
    )
    let interceptor = InputInterceptor { gesture in
      // Cheap early exit: no accessibility queries at all while nothing is guarded.
      guard guardedChats.hasAny else { return .pass }
      guard let sendGesture = gesture.sendGesture else {
        return coordinator.handleEscape() == .swallow ? .swallow : .pass
      }
      return coordinator.handle(sendGesture) == .swallow ? .swallow : .pass
    }
    self.interceptor = interceptor

    let settingsWindow = SettingsWindowController(
      model: SettingsModel(
        guardedChats: guardedChats,
        preferences: preferences,
        edition: edition,
        screens: screens,
        permission: permission,
        language: LanguageSetting(),
        protectionStatus: { interceptor.isRunning }
      ))
    self.settingsWindow = settingsWindow

    let statusMenu = StatusMenuController(
      guardedChats: guardedChats,
      preferences: preferences,
      screens: screens,
      permission: permission,
      isProtectionActive: { interceptor.isRunning },
      openSettings: { settingsWindow.show() },
      requestAccess: { messenger in
        edition.requestAccess(to: messenger, openPlan: { settingsWindow.show(pane: .general) })
      },
      updater: edition.updater
    )
    self.statusMenu = statusMenu

    let monitor = ConversationMonitor(
      screens: screens,
      guardedChats: guardedChats,
      memory: memory,
      preferences: preferences,
      badge: BadgeOverlay(),
      onShieldChange: { statusMenu.showShield(alerting: $0) }
    )
    monitor.start()
    self.monitor = monitor

    permission.whenGranted { [logger] in
      do {
        try interceptor.start()
        logger.info("Protection active")
      } catch {
        logger.error("Could not start input interception: \(error)")
        ErrorPresenter.show(
          title: String(
            localized: "Couldn’t start protection", bundle: .localization,
            comment: "Error alert title when input interception fails."),
          error: error)
      }
    }

    // First run: nothing guarded yet, so show people where to start.
    if !guardedChats.hasAny {
      settingsWindow.show(pane: .chats)
    }
  }
}

extension InputGesture {
  /// `nil` for Escape, which never sends.
  fileprivate var sendGesture: SendGesture? {
    switch self {
    case .returnKey(let withCommand, let targetProcess):
      .returnKey(withCommand: withCommand, targetProcess: targetProcess)
    case .click(let point): .click(at: point)
    case .escapeKey: nil
    }
  }
}
