import GuardedChats
import SwiftUI

/// The settings window: a searchable sidebar with neutral pane icons, native grouped forms on
/// the right, back and forward buttons in the toolbar. The sidebar, toolbar and controls are
/// the system ones, so they become Liquid Glass on macOS 26 and later and stay as they were on
/// older systems.
struct SettingsView: View {
  @Bindable var model: SettingsModel
  @State private var query = ""

  var body: some View {
    // Always shows the sidebar: there is no toggle, and dragging it shut snaps it back.
    NavigationSplitView(columnVisibility: .constant(.all)) {
      Sidebar(model: model, query: query)
        // Must sit on the sidebar column itself to take effect.
        .toolbar(removing: .sidebarToggle)
        // Honored when rendering screenshots; the live window also pins it in AppKit
        // (see SettingsWindowController), because there SwiftUI lets the divider move.
        .navigationSplitViewColumnWidth(
          min: SettingsWindowController.sidebarWidth,
          ideal: SettingsWindowController.sidebarWidth,
          max: SettingsWindowController.sidebarWidth
        )
    } detail: {
      Group {
        switch model.pane {
        case .chats: ChatsPane(model: model)
        case .behavior: BehaviorPane(model: model)
        case .appearance: AppearancePane(model: model)
        case .general: GeneralPane(model: model)
        }
      }
      .id(model.pane)
      // Like System Settings: the pane's name sits in the toolbar.
      .navigationTitle(model.pane.title)
      .toolbar {
        ToolbarItem(placement: .navigation) {
          ControlGroup {
            Button {
              model.goBack()
            } label: {
              Label(
                String(
                  localized: "Back", bundle: .localization,
                  comment: "Settings toolbar button: previous pane."),
                systemImage: "chevron.left")
            }
            .disabled(model.backHistory.isEmpty)
            Button {
              model.goForward()
            } label: {
              Label(
                String(
                  localized: "Forward", bundle: .localization,
                  comment: "Settings toolbar button: next pane."),
                systemImage: "chevron.right")
            }
            .disabled(model.forwardHistory.isEmpty)
          }
          .controlGroupStyle(.navigation)
        }
      }
    }
    .searchable(
      text: $query, placement: .sidebar,
      prompt: String(
        localized: "Search settings…", bundle: .localization,
        comment: "Placeholder of the search field in the settings sidebar.")
    )
    .frame(minWidth: 820, minHeight: 580)
  }
}

private struct Sidebar: View {
  let model: SettingsModel
  let query: String

  private var panes: [SettingsModel.Pane] {
    let query = query.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return SettingsModel.Pane.allCases }
    return SettingsModel.Pane.allCases.filter { pane in
      ([pane.title] + pane.keywords).contains { $0.localizedStandardContains(query) }
    }
  }

  var body: some View {
    // Own rows instead of List selection: the system highlight uses the accent color, while
    // Raycast-style settings mark the current pane with a neutral gray.
    ScrollView {
      VStack(spacing: 2) {
        ForEach(panes) { pane in
          SidebarRow(pane: pane, isSelected: model.pane == pane) { model.select(pane) }
        }
      }
      .padding(.horizontal, 10)
      .padding(.top, 8)
    }
    .scrollIndicators(.never)
    .overlay {
      if panes.isEmpty {
        Text(
          String(
            localized: "No results", bundle: .localization,
            comment: "Settings sidebar search found nothing.")
        )
        .font(.system(size: 12)).foregroundStyle(Theme.secondaryText)
      }
    }
    .safeAreaInset(edge: .bottom) {
      ProtectionStatus(model: model).padding(12)
    }
  }
}

private struct SidebarRow: View {
  let pane: SettingsModel.Pane
  let isSelected: Bool
  let select: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: select) {
      HStack(spacing: 10) {
        PaneIcon(pane: pane)
        Text(pane.title).font(.system(size: 13))
        Spacer(minLength: 0)
      }
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 8)
      .frame(height: 34)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(isSelected ? Theme.selection : (isHovered ? Theme.hover : .clear))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}

/// A neutral tile with the pane's glyph, like the icons in Raycast's sidebar: light in light
/// mode, dark gray in dark mode, never colored.
private struct PaneIcon: View {
  let pane: SettingsModel.Pane

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
    Image(systemName: pane.symbol)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Theme.tileGlyph)
      .frame(width: 24, height: 24)
      .background(
        LinearGradient(
          colors: [Theme.tileTop, Theme.tileBottom], startPoint: .top, endPoint: .bottom),
        in: shape
      )
      .overlay(shape.strokeBorder(Theme.stroke))
  }
}

extension SettingsModel.Pane {
  /// Setting names the sidebar search also matches, so "login" finds General.
  fileprivate var keywords: [String] {
    switch self {
    case .chats:
      [
        String(
          localized: "Guarded chats", bundle: .localization,
          comment: "Settings search keyword for the Chats pane."),
        "WhatsApp", "Slack",
      ]
    case .behavior:
      [
        String(
          localized: "Ask again after silence", bundle: .localization,
          comment: "Behavior setting."),
        String(
          localized: "Hold time", bundle: .localization,
          comment: "Behavior setting for the Undo mode."),
        String(
          localized: "Default for new chats", bundle: .localization,
          comment: "Behavior pane section."),
      ]
    case .appearance:
      [
        String(
          localized: "Message box badge", bundle: .localization,
          comment: "Appearance pane section."),
        String(
          localized: "Menu bar", bundle: .localization, comment: "Appearance pane section."),
      ]
    case .general:
      [
        String(
          localized: "Open at login", bundle: .localization, comment: "General setting."),
        String(
          localized: "Permission", bundle: .localization, comment: "General pane section."),
        String(
          localized: "Privacy", bundle: .localization, comment: "General pane section."),
        String(
          localized: "Language", bundle: .localization, comment: "General pane section."),
      ]
    }
  }
}

private struct ProtectionStatus: View {
  let model: SettingsModel
  @State private var showsGuardedChats = false

  private enum Status {
    /// Permission missing or interception not running: nothing can be protected.
    case off
    /// Working, but no chat is guarded yet, so nothing is actually protected.
    case idle
    case on
  }

  private var state: Status {
    guard model.isPermissionGranted && model.isProtectionActive else { return .off }
    return model.guardedChats.activeChats.isEmpty ? .idle : .on
  }

  var body: some View {
    let state = state
    let color: Color =
      switch state {
      case .off: Theme.signal
      case .idle: .yellow
      case .on: .green
      }
    HStack(spacing: 8) {
      Circle()
        .fill(color)
        .frame(width: 7, height: 7)
        .shadow(color: color.opacity(0.6), radius: 3)
      Text(title(for: state))
        .font(.system(size: 12, weight: .semibold))
        // Label lengths differ per language: shrink a little rather than wrap.
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .layoutPriority(1)
      Spacer(minLength: 4)
      if state == .on {
        Text(
          String(
            localized: "\(model.guardedChats.activeChats.count) chats", bundle: .localization,
            comment: "Settings sidebar: number of guarded chats.")
        )
        .font(.system(size: 11)).foregroundStyle(Theme.secondaryText)
        .fixedSize()
        Image(systemName: "chevron.up")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(Theme.secondaryText)
          .rotationEffect(.degrees(showsGuardedChats ? 180 : 0))
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 36)
    .glassSurface(in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
    .contentShape(Rectangle())
    .onTapGesture {
      switch state {
      case .off: model.select(.general)
      case .idle: model.select(.chats)
      case .on: showsGuardedChats.toggle()
      }
    }
    // Opens upward from the bottom of the sidebar, listing what is protected right now.
    .popover(isPresented: $showsGuardedChats, arrowEdge: .top) {
      GuardedChatsPopover(model: model) { showsGuardedChats = false }
    }
    .animation(.snappy(duration: 0.2), value: showsGuardedChats)
  }

  private func title(for state: Status) -> String {
    switch state {
    case .off:
      String(
        localized: "Protection off", bundle: .localization, comment: "Settings sidebar status.")
    case .idle:
      String(
        localized: "No guarded chats yet", bundle: .localization,
        comment: "Chats pane empty state title.")
    case .on:
      String(
        localized: "Protection on", bundle: .localization, comment: "Settings sidebar status.")
    }
  }
}

/// The guarded chats at a glance, opened from the protection status. Choosing a chat shows it
/// under Chats, where its mode can be changed.
private struct GuardedChatsPopover: View {
  let model: SettingsModel
  let close: () -> Void

  var body: some View {
    let chats = model.guardedChats.chats
    VStack(alignment: .leading, spacing: 4) {
      Text(
        String(
          localized: "Guarded chats · \(chats.count)", bundle: .localization,
          comment: "Chats pane section with the number of guarded chats.")
      )
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.top, 2)
      ScrollView {
        VStack(spacing: 2) {
          ForEach(chats, id: \.id) { chat in
            GuardedChatPopoverRow(chat: chat) {
              model.select(.chats)
              close()
            }
          }
        }
      }
      .scrollBounceBehavior(.basedOnSize)
      .frame(maxHeight: 320)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(8)
    .frame(width: 280)
  }
}

private struct GuardedChatPopoverRow: View {
  let chat: GuardedChat
  let select: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: select) {
      HStack(spacing: 10) {
        Image(nsImage: .appGlyph(chat.id.messenger.glyph))
          .renderingMode(.template)
          .foregroundStyle(.secondary)
          .frame(width: 20)
        VStack(alignment: .leading, spacing: 1) {
          Text(chat.id.name.value).lineLimit(1)
          Text(chat.id.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer(minLength: 8)
        Image(systemName: chat.isPaused ? "pause.circle" : chat.mode.symbol)
          .foregroundStyle(.secondary)
          .help(
            chat.isPaused
              ? String(
                localized: "Paused", bundle: .localization,
                comment: "Chats pane: a guarded chat that is switched off for now.")
              : chat.mode.title)
      }
      .opacity(chat.isPaused ? 0.55 : 1)
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(isHovered ? Theme.selection : .clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
