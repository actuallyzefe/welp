import SharedKernel
import SwiftUI

/// What an edition of Welp adds to the open-source core.
///
/// The core guards WhatsApp and runs on its own (`CoreEdition`). Welp Pro, in `ee/`, is an
/// edition that adds more messengers and a license; the core never depends on it.
@MainActor
public protocol WelpEdition: AnyObject {
  /// Integrations for messengers beyond the core's WhatsApp. Called once at launch.
  /// `postReturnKey` sends a Return (or ⌘↩) to the frontmost app, to replay a held send.
  func makeScreens(postReturnKey: @escaping @MainActor (_ withCommand: Bool) -> Void)
    -> [any MessengerScreen]

  /// Whether chats in `messenger` can be guarded right now. Read from SwiftUI views, so an
  /// observable source (such as a license) updates the UI when it changes.
  func isAvailable(_ messenger: Messenger) -> Bool

  /// Called when someone tries to guard a chat in a messenger that isn't available.
  /// `openPlan` shows the plan settings (`planSection()`).
  func requestAccess(to messenger: Messenger, openPlan: @escaping @MainActor () -> Void)

  /// Shown at the top of the General settings, e.g. the plan and license key.
  func planSection() -> AnyView?

  /// Keeps the app up to date, if this edition is distributed with updates. Read once the
  /// app has finished launching.
  var updater: (any AppUpdater)? { get }
}

/// Finds and installs new versions of the app (the official app uses Sparkle).
@MainActor
public protocol AppUpdater: AnyObject {
  /// Whether a check can start now (not while one is running).
  var canCheckForUpdates: Bool { get }
  /// Checks in the background about once a day. The user's choice, remembered.
  var automaticallyChecksForUpdates: Bool { get set }
  /// Checks now, showing the result.
  func checkForUpdates()
}

/// The open-source core on its own: WhatsApp, in any number of chats.
public final class CoreEdition: WelpEdition {
  public init() {}

  public func makeScreens(postReturnKey: @escaping @MainActor (_ withCommand: Bool) -> Void)
    -> [any MessengerScreen]
  { [] }

  public func isAvailable(_ messenger: Messenger) -> Bool { false }

  public func requestAccess(to messenger: Messenger, openPlan: @escaping @MainActor () -> Void) {}

  public func planSection() -> AnyView? { nil }

  /// Built from source: updated by building again, not from the official app's feed.
  public var updater: (any AppUpdater)? { nil }
}
