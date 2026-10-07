import AppKit

/// The menu bar shown while the settings window is open.
///
/// Welp has no menus of its own, but text fields still need one: macOS routes ⌘V, ⌘C and
/// the other editing shortcuts through the Edit menu, and without it they do nothing.
@MainActor
enum MainMenu {
  static func make() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(submenu(title: "Welp", items: appItems()))
    menu.addItem(
      submenu(
        title: String(localized: "Edit", bundle: .localization, comment: "Main menu title."),
        items: editItems()))
    menu.addItem(
      submenu(
        title: String(localized: "Window", bundle: .localization, comment: "Main menu title."),
        items: windowItems()))
    return menu
  }

  private static func appItems() -> [NSMenuItem] {
    [
      item(
        String(localized: "Hide Welp", bundle: .localization, comment: "Main menu item."),
        #selector(NSApplication.hide(_:)), "h"),
      .separator(),
      item(
        String(localized: "Quit Welp", bundle: .localization, comment: "Menu bar menu item."),
        #selector(NSApplication.terminate(_:)), "q"),
    ]
  }

  private static func editItems() -> [NSMenuItem] {
    let redo = item(
      String(localized: "Redo", bundle: .localization, comment: "Edit menu item."),
      Selector(("redo:")), "z")
    redo.keyEquivalentModifierMask = [.command, .shift]
    return [
      item(
        String(localized: "Undo", bundle: .localization, comment: "Edit menu item."),
        Selector(("undo:")), "z"),
      redo,
      .separator(),
      item(
        String(localized: "Cut", bundle: .localization, comment: "Edit menu item."),
        #selector(NSText.cut(_:)), "x"),
      item(
        String(localized: "Copy", bundle: .localization, comment: "Edit menu item."),
        #selector(NSText.copy(_:)), "c"),
      item(
        String(localized: "Paste", bundle: .localization, comment: "Edit menu item."),
        #selector(NSText.paste(_:)), "v"),
      item(
        String(localized: "Select All", bundle: .localization, comment: "Edit menu item."),
        #selector(NSText.selectAll(_:)), "a"),
    ]
  }

  private static func windowItems() -> [NSMenuItem] {
    [
      item(
        String(localized: "Close", bundle: .localization, comment: "Window menu item."),
        #selector(NSWindow.performClose(_:)), "w")
    ]
  }

  private static func submenu(title: String, items: [NSMenuItem]) -> NSMenuItem {
    let submenu = NSMenu(title: title)
    items.forEach(submenu.addItem)
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.submenu = submenu
    return item
  }

  /// Sent to the first responder, like the standard menus, so it reaches the focused field.
  private static func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
    NSMenuItem(title: title, action: action, keyEquivalent: key)
  }
}
