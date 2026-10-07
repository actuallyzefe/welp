import AppKit
import GuardedChats
import Preferences
import SendGuard
import SharedKernel

/// Watches the frontmost messenger a few times per second and keeps everything that
/// depends on "where am I?" up to date: first-message approvals, the composer badge and
/// the menu bar icon. Only runs Accessibility queries while a messenger is frontmost.
@MainActor
final class ConversationMonitor {
  private static let interval: TimeInterval = 0.4

  private let screens: [any MessengerScreen]
  private let guardedChats: GuardedChatsService
  private let memory: ApprovalMemory
  private let preferences: PreferencesService
  private let badge: BadgeOverlay
  private let onShieldChange: @MainActor (_ isAlerting: Bool) -> Void
  private var timer: Timer?
  private var isAlerting = false

  init(
    screens: [any MessengerScreen],
    guardedChats: GuardedChatsService,
    memory: ApprovalMemory,
    preferences: PreferencesService,
    badge: BadgeOverlay,
    onShieldChange: @escaping @MainActor (_ isAlerting: Bool) -> Void
  ) {
    self.screens = screens
    self.guardedChats = guardedChats
    self.memory = memory
    self.preferences = preferences
    self.badge = badge
    self.onShieldChange = onShieldChange
  }

  func start() {
    timer?.invalidate()
    let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func tick() {
    let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    let snapshot = screens.first { $0.bundleIdentifier == frontmost }?.conversationSnapshot()

    if let snapshot {
      memory.activeChatChanged(in: snapshot.messenger, to: snapshot.chat)
    }

    let settings = preferences.current
    let guarded = snapshot?.chat.flatMap { chat in guardedChats.mode(for: chat).map { (chat, $0) } }

    if let (chat, mode) = guarded, settings.showsComposerBadge,
      let frame = snapshot?.composerFrame
    {
      badge.show(chat: chat, mode: mode, above: frame)
    } else {
      badge.hide()
    }

    let shouldAlert = guarded != nil && settings.tintsMenuBarIcon
    if shouldAlert != isAlerting {
      isAlerting = shouldAlert
      onShieldChange(shouldAlert)
    }
  }
}
