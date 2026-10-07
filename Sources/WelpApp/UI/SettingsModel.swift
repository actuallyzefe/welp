import AppKit
import GuardedChats
import Observation
import Preferences
import ServiceManagement
import SharedKernel

/// State and actions behind the settings window.
@MainActor
@Observable
final class SettingsModel {
  enum Pane: String, CaseIterable, Identifiable {
    case chats, behavior, appearance, general

    var id: Self { self }

    var title: String {
      switch self {
      case .chats: String(localized: "Chats", bundle: .localization, comment: "Settings section.")
      case .behavior:
        String(localized: "Behavior", bundle: .localization, comment: "Settings section.")
      case .appearance:
        String(localized: "Appearance", bundle: .localization, comment: "Settings section.")
      case .general:
        String(localized: "General", bundle: .localization, comment: "Settings section.")
      }
    }

    var symbol: String {
      switch self {
      case .chats: "bubble.left.and.bubble.right.fill"
      case .behavior: "slider.horizontal.3"
      case .appearance: "sparkles"
      case .general: "gearshape.fill"
      }
    }
  }

  var pane = Pane.chats
  /// Panes visited before / after the current one, for the back and forward buttons.
  private(set) var backHistory: [Pane] = []
  private(set) var forwardHistory: [Pane] = []
  let guardedChats: GuardedChatsService
  let preferences: PreferencesService
  let edition: any WelpEdition

  /// Conversations currently open in running messengers.
  private(set) var openChats: [ChatID] = []
  private(set) var runningMessengers: [Messenger] = []
  private(set) var isPermissionGranted = false
  private(set) var isProtectionActive = false
  private(set) var launchesAtLogin = false
  /// The interface language picked in Welp; `nil` follows the Mac.
  private(set) var language: String?

  @ObservationIgnored let languageSetting: LanguageSetting
  /// The language Welp is running in; a different choice needs a relaunch.
  @ObservationIgnored private let launchLanguage: String?

  @ObservationIgnored private let screens: [any MessengerScreen]
  @ObservationIgnored private let permission: AccessibilityPermission
  @ObservationIgnored private let protectionStatus: @MainActor () -> Bool
  @ObservationIgnored private var refreshTimer: Timer?

  init(
    guardedChats: GuardedChatsService,
    preferences: PreferencesService,
    edition: any WelpEdition,
    screens: [any MessengerScreen],
    permission: AccessibilityPermission,
    language: LanguageSetting,
    protectionStatus: @escaping @MainActor () -> Bool
  ) {
    self.guardedChats = guardedChats
    self.preferences = preferences
    self.edition = edition
    self.screens = screens
    self.permission = permission
    self.protectionStatus = protectionStatus
    self.languageSetting = language
    self.language = language.selection
    self.launchLanguage = language.selection
  }

  // MARK: Navigation

  /// Shows a pane and remembers the current one for "back".
  func select(_ pane: Pane) {
    guard pane != self.pane else { return }
    backHistory.append(self.pane)
    forwardHistory.removeAll()
    self.pane = pane
  }

  func goBack() {
    guard let previous = backHistory.popLast() else { return }
    forwardHistory.append(pane)
    pane = previous
  }

  func goForward() {
    guard let next = forwardHistory.popLast() else { return }
    backHistory.append(pane)
    pane = next
  }

  // MARK: Live refresh (only while the window is open)

  func startRefreshing() {
    refresh()
    refreshTimer?.invalidate()
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.refresh() }
    }
  }

  func stopRefreshing() {
    refreshTimer?.invalidate()
    refreshTimer = nil
  }

  /// The app behind a messenger, e.g. for showing its icon.
  func bundleIdentifier(of messenger: Messenger) -> String? {
    screens.first { $0.messenger == messenger }?.bundleIdentifier
  }

  private func refresh() {
    let running = screens.filter(\.isRunning)
    runningMessengers = running.map(\.messenger)
    openChats = running.compactMap { $0.activeChat() }
    isPermissionGranted = permission.isGranted
    isProtectionActive = protectionStatus()
    launchesAtLogin = SMAppService.mainApp.status == .enabled
    language = languageSetting.selection  // May also change in System Settings.
  }

  // MARK: Chats

  func protect(_ chat: ChatID) {
    guard guardedChats.isAvailable(chat.messenger) else {
      requestAccess(to: chat.messenger)
      return
    }
    // A paused chat picks up where it left off, with its own mode.
    if guardedChats.isPaused(chat) {
      setPaused(false, for: chat)
    } else {
      perform { try guardedChats.protect(chat, mode: preferences.current.defaultMode) }
    }
  }

  func requestAccess(to messenger: Messenger) {
    edition.requestAccess(to: messenger) { [weak self] in self?.select(.general) }
  }

  func setMode(_ mode: ProtectionMode, for chat: ChatID) {
    perform { try guardedChats.setMode(mode, for: chat) }
  }

  /// Pauses a guarded chat (kept with its mode, not guarded) or resumes it.
  func setPaused(_ isPaused: Bool, for chat: ChatID) {
    guard isPaused || guardedChats.isAvailable(chat.messenger) else {
      requestAccess(to: chat.messenger)
      return
    }
    perform { try guardedChats.setPaused(isPaused, for: chat) }
  }

  func unguard(_ chat: ChatID) {
    perform { try guardedChats.unguard(chat) }
  }

  // MARK: Preferences

  func update(_ change: (inout Preferences) -> Void) {
    perform { try preferences.update(change) }
  }

  func setLaunchesAtLogin(_ enabled: Bool) {
    let service = SMAppService.mainApp
    perform { enabled ? try service.register() : try service.unregister() }
    launchesAtLogin = service.status == .enabled
  }

  // MARK: Language

  var languageNeedsRelaunch: Bool { language != launchLanguage }

  func setLanguage(_ language: String?) {
    languageSetting.select(language)
    self.language = languageSetting.selection
  }

  func relaunch() {
    Relauncher.relaunch(logger: OSLogLogger(category: "app"))
  }

  func openPermissionSettings() {
    permission.openSettings()
  }

  private func perform(_ change: () throws -> Void) {
    do {
      try change()
    } catch {
      ErrorPresenter.show(title: .settingNotSaved, error: error)
    }
  }
}
