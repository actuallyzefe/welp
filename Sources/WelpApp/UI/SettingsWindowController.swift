import AppKit
import SwiftUI

/// Hosts the SwiftUI settings in a unified-toolbar window, so the sidebar and toolbar get the
/// system look (Liquid Glass on macOS 26 and later).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
  private let model: SettingsModel
  private var window: NSWindow?

  init(model: SettingsModel) {
    self.model = model
  }

  func show(pane: SettingsModel.Pane? = nil) {
    if let pane { model.select(pane) }
    let window = window ?? makeWindow()
    self.window = window
    model.startRefreshing()
    // Welp normally lives only in the menu bar; while settings are open it also gets a Dock
    // icon, so the window can be found with ⌘Tab and the Dock like any other.
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    keepsSearchUnfocused = true
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    model.stopRefreshing()
    NSApp.setActivationPolicy(.accessory)
  }

  static let sidebarWidth: CGFloat = 230
  private weak var sidebarItem: NSSplitViewItem?
  private var sidebarObservations: [NSKeyValueObservation] = []

  /// True from opening the window until the first click or key press in it.
  private var keepsSearchUnfocused = false

  /// Runs after every event the window handles.
  func windowDidUpdate(_ notification: Notification) {
    releaseInitialFocus()
    pinSidebar()
  }

  /// Opens the window with nothing focused. SwiftUI installs the sidebar search a moment after
  /// the window appears and hands it the focus, which leaves the field highlighted; until the
  /// person clicks or types, take that focus back. Clicking the field or ⌘F still focuses it.
  private func releaseInitialFocus() {
    guard keepsSearchUnfocused, let window else { return }
    if let event = NSApp.currentEvent, event.window === window,
      [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .keyDown]
        .contains(event.type)
    {
      keepsSearchUnfocused = false
    } else if window.firstResponder is NSTextView {
      window.makeFirstResponder(nil)
    }
  }

  /// Pins the sidebar once SwiftUI has created it; a no-op afterwards.
  private func pinSidebar() {
    guard sidebarItem == nil, let sidebar = findSidebarItem() else { return }
    sidebarItem = sidebar
    Self.pin(sidebar)
    // SwiftUI resets the item's limits on its own updates (e.g. switching panes): pin it
    // again the moment that happens.
    let repin: @Sendable (NSSplitViewItem, NSKeyValueObservedChange<CGFloat>) -> Void = {
      [weak self] _, _ in
      MainActor.assumeIsolated {
        if let item = self?.sidebarItem { Self.pin(item) }
      }
    }
    sidebarObservations = [
      sidebar.observe(\.maximumThickness, changeHandler: repin),
      sidebar.observe(\.minimumThickness, changeHandler: repin),
    ]
  }

  /// Keeps the sidebar at a fixed width. NavigationSplitView ignores
  /// `.navigationSplitViewColumnWidth` on macOS and lets the divider be dragged, so the
  /// underlying split view item is pinned directly.
  private static func pin(_ sidebar: NSSplitViewItem) {
    if sidebar.canCollapse { sidebar.canCollapse = false }
    if sidebar.minimumThickness != sidebarWidth { sidebar.minimumThickness = sidebarWidth }
    if sidebar.maximumThickness != sidebarWidth { sidebar.maximumThickness = sidebarWidth }
  }

  private func findSidebarItem() -> NSSplitViewItem? {
    func splitViews(in view: NSView) -> [NSSplitView] {
      (view as? NSSplitView).map { [$0] } ?? view.subviews.flatMap(splitViews)
    }
    guard let contentView = window?.contentView else { return nil }
    return splitViews(in: contentView).lazy
      .compactMap { ($0.delegate as? NSSplitViewController)?.splitViewItems }
      .compactMap { $0.first { $0.behavior == .sidebar } }
      .first
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 880, height: 640),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    let hosting = NSHostingController(rootView: SettingsView(model: model))
    // Lets SwiftUI's `.toolbar`, `.searchable` and `.navigationTitle` reach this AppKit window.
    hosting.sceneBridgingOptions = [.toolbars, .title]
    window.contentViewController = hosting
    window.setContentSize(NSSize(width: 880, height: 640))
    window.toolbarStyle = .unified
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.center()
    window.setFrameAutosaveName("WelpSettings")
    return window
  }
}
