import AppKit
import GuardedChats
import Preferences
import SharedKernel

/// Menu bar "W!" mark. Turns red while you are in a guarded chat; its menu offers quick
/// toggles for the chats open right now and the way into the settings window.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
  private static let maxLabelLength = 40

  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let guardedChats: GuardedChatsService
  private let preferences: PreferencesService
  private let screens: [any MessengerScreen]
  private let permission: AccessibilityPermission
  private let isProtectionActive: @MainActor () -> Bool
  private let openSettings: @MainActor () -> Void
  private let requestAccess: @MainActor (Messenger) -> Void
  private let updater: (any AppUpdater)?

  init(
    guardedChats: GuardedChatsService,
    preferences: PreferencesService,
    screens: [any MessengerScreen],
    permission: AccessibilityPermission,
    isProtectionActive: @escaping @MainActor () -> Bool,
    openSettings: @escaping @MainActor () -> Void,
    requestAccess: @escaping @MainActor (Messenger) -> Void,
    updater: (any AppUpdater)?
  ) {
    self.guardedChats = guardedChats
    self.preferences = preferences
    self.screens = screens
    self.permission = permission
    self.isProtectionActive = isProtectionActive
    self.openSettings = openSettings
    self.requestAccess = requestAccess
    self.updater = updater
    super.init()

    showShield(alerting: false)
    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu
  }

  func showShield(alerting: Bool) {
    let image = alerting ? Self.alertingIcon : Self.icon
    image.accessibilityDescription =
      alerting
      ? String(
        localized: "Welp: guarded chat", bundle: .localization,
        comment: "VoiceOver label of the menu bar icon while in a guarded chat.")
      : "Welp"
    statusItem.button?.image = image
  }

  /// Welp's mark, as a template so it follows the menu bar's light/dark look.
  private static let icon: NSImage = {
    let image = NSImage.welpMark
    image.size = NSSize(width: 14.5, height: 15)
    return image
  }()

  /// The same mark in the signal color, shown while a guarded chat is open.
  private static let alertingIcon: NSImage = {
    let source = icon
    let image = NSImage(size: source.size, flipped: false) { rect in
      source.draw(in: rect)
      Theme.signalNSColor.set()
      rect.fill(using: .sourceAtop)
      return true
    }
    image.isTemplate = false
    return image
  }()

  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    menu.addItem(statusLine())
    // What is protected, with a switch for each; then what could be protected right now.
    for section in [guardedSection(), openChatsSection()] where !section.isEmpty {
      menu.addItem(.separator())
      section.forEach(menu.addItem)
    }
    menu.addItem(.separator())
    let settings = item(
      String(localized: "Settings…", bundle: .localization, comment: "Menu bar menu item."),
      action: #selector(showSettings), key: ",")
    settings.setMenuImage(Self.symbol("gearshape"))
    menu.addItem(settings)
    if updater != nil {
      let updates = item(.checkForUpdates, action: #selector(checkForUpdates))
      updates.setMenuImage(Self.symbol("arrow.triangle.2.circlepath"))
      updates.isEnabled = updater?.canCheckForUpdates ?? false
      menu.addItem(updates)
    }
    menu.addItem(
      item(
        String(localized: "Quit Welp", bundle: .localization, comment: "Menu bar menu item."),
        action: #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
  }

  // MARK: Items

  private func statusLine() -> NSMenuItem {
    if !permission.isGranted {
      let line = item(
        String(
          localized: "Accessibility permission required…", bundle: .localization,
          comment: "Menu bar status line; opens System Settings."),
        action: #selector(openPermissionSettings))
      line.setMenuImage(Self.symbol("exclamationmark.triangle"))
      return line
    }
    let count = guardedChats.activeChats.count
    let line: NSMenuItem
    if !isProtectionActive() {
      line = disabled(
        String(
          localized: "Protection couldn’t start", bundle: .localization,
          comment: "Menu bar status line."))
      line.setMenuImage(Self.symbol("exclamationmark.triangle"))
    } else if count == 0 {
      line = disabled(
        String(
          localized: "No guarded chats yet", bundle: .localization,
          comment: "Chats pane empty state title."))
      line.setMenuImage(Self.welpMenuMark)
    } else {
      line = disabled(
        String(
          localized: "Protection on · \(count) chats", bundle: .localization,
          comment: "Menu bar status line. The argument is the number of guarded chats."))
      line.setMenuImage(Self.welpMenuMark)
    }
    return line
  }

  /// Every guarded chat, checked while it is protected. Choosing one pauses or resumes it,
  /// like its switch in the settings.
  private func guardedSection() -> [NSMenuItem] {
    let chats = guardedChats.chats
    guard !chats.isEmpty else { return [] }
    let header = NSMenuItem.sectionHeader(
      title: String(
        localized: "Guarded chats", bundle: .localization,
        comment: "Menu bar menu: section with every guarded chat."))
    return [header]
      + chats.map { chat in
        let item = item(Self.shorten(chat.id.name.value), action: #selector(togglePaused(_:)))
        item.representedObject = chat.id
        item.toolTip = chat.id.description
        item.state =
          !chat.isPaused && guardedChats.isAvailable(chat.id.messenger) ? .on : .off
        item.setMenuImage(.appGlyph(chat.id.messenger.glyph, size: 15))
        return item
      }
  }

  /// The chats open right now in a running messenger that aren't guarded yet: one choice
  /// protects them. Guarded ones are already listed above.
  private func openChatsSection() -> [NSMenuItem] {
    let header = NSMenuItem.sectionHeader(
      title: String(
        localized: "Open right now", bundle: .localization,
        comment: "Chats pane section: chats currently open in WhatsApp or Slack."))
    let running = screens.filter(\.isRunning)
    guard !running.isEmpty else {
      let line = disabled(
        String(
          localized: "WhatsApp or Slack isn’t open", bundle: .localization,
          comment: "Menu bar menu, when neither messenger is running."))
      line.setMenuImage(Self.symbol("bubble.left.and.bubble.right"))
      return [header, line]
    }

    let items: [NSMenuItem] = running.compactMap { screen in
      let icon = NSImage.appGlyph(screen.messenger.glyph, size: 15)
      guard let chat = screen.activeChat() else {
        let line = disabled(
          String(
            localized: "\(screen.messenger.displayName): open a chat to protect it",
            bundle: .localization,
            comment: "Menu bar menu. The argument is WhatsApp or Slack."))
        line.setMenuImage(icon)
        return line
      }
      guard !guardedChats.chats.contains(where: { $0.id == chat }) else { return nil }
      let protect = item(
        String(
          localized: "Protect “\(Self.shorten(chat.name.value))”", bundle: .localization,
          comment: "Menu bar menu: guards a chat open right now. The argument is the chat name."),
        action: #selector(protect(_:)))
      protect.representedObject = chat
      protect.toolTip = chat.description
      protect.setMenuImage(icon)
      return protect
    }
    return items.isEmpty ? [] : [header] + items
  }

  // MARK: Actions

  @objc private func togglePaused(_ sender: NSMenuItem) {
    guard let chat = sender.representedObject as? ChatID else { return }
    // A chat whose app this plan doesn't include is off either way; offer to unlock it.
    guard guardedChats.isAvailable(chat.messenger) else {
      requestAccess(chat.messenger)
      return
    }
    perform { try guardedChats.setPaused(!guardedChats.isPaused(chat), for: chat) }
  }

  @objc private func protect(_ sender: NSMenuItem) {
    guard let chat = sender.representedObject as? ChatID else { return }
    perform { try guardedChats.protect(chat, mode: preferences.current.defaultMode) }
  }

  private func perform(_ change: () throws -> Void) {
    do {
      try change()
    } catch GuardedChatsError.messengerUnavailable(let messenger) {
      requestAccess(messenger)
    } catch {
      ErrorPresenter.show(title: .settingNotSaved, error: error)
    }
  }

  @objc private func checkForUpdates() {
    updater?.checkForUpdates()
  }

  @objc private func showSettings() {
    openSettings()
  }

  @objc private func openPermissionSettings() {
    permission.openSettings()
  }

  // MARK: Helpers

  private func item(
    _ title: String, action: Selector, key: String = "", target: AnyObject? = nil
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = target ?? self
    return item
  }

  private func disabled(_ title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
  }

  /// Welp's mark at menu icon size, for the status line.
  private static var welpMenuMark: NSImage {
    let image = NSImage.welpMark
    image.size = NSSize(width: 13.5, height: 14)
    return image
  }

  /// A menu-sized, monochrome outline SF Symbol that follows the menu's look, like Raycast's.
  private static func symbol(_ name: String) -> NSImage? {
    NSImage(systemSymbolName: name, accessibilityDescription: nil)?
      .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
  }

  private static func shorten(_ text: String) -> String {
    text.count <= maxLabelLength ? text : text.prefix(maxLabelLength - 1) + "…"
  }
}

extension NSMenuItem {
  /// Sets the item's icon and keeps it visible. macOS 27 hides menu item symbol images unless
  /// the item opts in with `preferredImageVisibility = .visible`; the SDK Welp builds with
  /// predates that API, so it is set by key where the system has it.
  fileprivate func setMenuImage(_ image: NSImage?) {
    self.image = image
    let key = "preferredImageVisibility"
    if responds(to: NSSelectorFromString(key)) {
      setValue(1, forKey: key)  // NSMenuItem.ImageVisibility.visible
    }
  }
}
