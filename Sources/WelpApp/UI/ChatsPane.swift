import AppKit
import GuardedChats
import SharedKernel
import SwiftUI

/// Two clearly separate jobs: protect the chat that is open right now (with the one call to
/// action in Welp's red), and see what is already protected, filtered by app. Apps that are on
/// the way have their own "Soon" filter.
struct ChatsPane: View {
  let model: SettingsModel
  @State private var filter = ChatFilter.all

  var body: some View {
    let messengers = Messenger.allCases.filter(model.showsApp)
    Form {
      ProtectNowSection(model: model)

      // The filter sits in the header of the first section below it, above the app's name.
      switch filter {
      case .all:
        ForEach(Array(messengers.enumerated()), id: \.element) { index, messenger in
          AppSection(model: model, messenger: messenger) {
            if index == 0 { filterPicker(messengers) }
          }
        }
      case .app(let messenger):
        AppSection(model: model, messenger: messenger) { filterPicker(messengers) }
      }
    }
    .formStyle(.grouped)
  }

  /// All · WhatsApp · Slack · Discord (Soon) · Teams (Soon), each with its app's icon.
  private func filterPicker(_ messengers: [Messenger]) -> some View {
    var segments = [
      AppFilterBar.Segment(
        filter: .all,
        title: String(
          localized: "All", bundle: .localization,
          comment: "Chats pane filter: guarded chats in every app."),
        image: .segmentSymbol("square.grid.2x2"))
    ]
    segments += messengers.map { messenger in
      AppFilterBar.Segment(
        filter: .app(messenger), title: messenger.displayName,
        image: .segmentIcon(
          bundleIdentifier: model.bundleIdentifier(of: messenger), glyph: messenger.glyph))
    }
    segments += UpcomingApp.all.map { app in
      AppFilterBar.Segment(
        id: app.id, filter: nil, title: app.name,
        image: .segmentIcon(bundleIdentifier: app.bundleIdentifier, glyph: app.glyph),
        isSoon: true)
    }
    return AppFilterBar(segments: segments, selection: $filter)
      // Section headers are inset to the rows' text; reach out to the cards' edges instead.
      .padding(.horizontal, -10)
      .padding(.bottom, 16)
  }
}

/// A roomy segmented filter: each app's icon and name, the chosen one on a raised neutral
/// knob that slides between them.
private struct AppFilterBar: View {
  struct Segment {
    var id: String?
    /// `nil` for an app that isn't supported yet: shown, but can't be chosen.
    let filter: ChatFilter?
    let title: String
    let image: NSImage
    var isSoon = false

    var identity: String {
      switch filter {
      case .all: "all"
      case .app(let messenger): messenger.rawValue
      case nil: id ?? title
      }
    }
  }

  let segments: [Segment]
  @Binding var selection: ChatFilter
  @Namespace private var knob
  @State private var availableWidth: CGFloat?
  @State private var idealWidths: [Density: CGFloat] = [:]

  /// How much of each segment fits: everything, without the "Soon" tags, or icons only.
  enum Density: CaseIterable { case full, compact, iconsOnly }

  /// A narrow window or a longer language drops detail rather than truncating names.
  private var density: Density {
    guard let availableWidth else { return .full }
    return Density.allCases.first { (idealWidths[$0] ?? .infinity) <= availableWidth }
      ?? .iconsOnly
  }

  var body: some View {
    // Only one bar is ever shown. `ViewThatFits` would keep all three in the hierarchy, and
    // their sliding knobs make AppKit's constraint passes loop until it stops the app (seen
    // on macOS 15). Hidden, static copies measure what each density needs instead.
    VStack(spacing: 0) {
      // Always as wide as offered, whichever bar is shown, so the choice can't feed back.
      Color.clear.frame(height: 0).onWidthChange { availableWidth = $0 }
      bar(density, knob: knob)
    }
    .background {
      ZStack {
        ForEach(Density.allCases, id: \.self) { density in
          bar(density, knob: nil)
            .fixedSize()
            .onWidthChange { idealWidths[density] = $0 }
        }
      }
      .hidden()
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      String(
        localized: "Apps", bundle: .localization,
        comment: "Accessibility label of the Chats pane's app filter."))
  }

  /// The bar at `density`. Without a `knob` namespace it is a static copy for measuring,
  /// with every name in the selected (wider) weight.
  private func bar(_ density: Density, knob: Namespace.ID?) -> some View {
    HStack(spacing: 4) {
      ForEach(segments, id: \.identity) { segment in
        SegmentButton(
          segment: segment, density: density,
          isSelected: knob == nil || segment.filter == selection, knob: knob
        ) {
          guard let filter = segment.filter else { return }
          // Not animated: the form below changes its sections, and on macOS 15 an animated
          // change to a form's rows loops AppKit's constraint passes until it stops the app.
          selection = filter
        }
      }
    }
    .padding(4)
    .background(Theme.raisedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

private struct SegmentButton: View {
  let segment: AppFilterBar.Segment
  let density: AppFilterBar.Density
  let isSelected: Bool
  let knob: Namespace.ID?
  let select: () -> Void
  @State private var isHovered = false

  var body: some View {
    let isSoon = segment.filter == nil
    Button(action: select) {
      HStack(spacing: 7) {
        Image(nsImage: segment.image)
          .frame(width: 16, height: 16)
        if density != .iconsOnly {
          Text(segment.title)
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            // Never truncate: segments take their content's width and share what is left.
            .fixedSize()
        }
        if segment.isSoon && density == .full {
          Text(
            String(
              localized: "Soon", bundle: .localization,
              comment: "Tag on a messenger that Welp doesn't support yet.")
          )
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Theme.raisedSurface, in: Capsule())
          .fixedSize()
        }
      }
      .foregroundStyle(isSelected ? Theme.ink : Theme.secondaryText)
      // Without the tag, "soon" apps read as not there yet.
      .opacity(segment.isSoon && density != .full && !isSelected ? 0.6 : 1)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity)
      .frame(height: 38)
      .background {
        if isSelected, let knob {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.knob)
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            .matchedGeometryEffect(id: "knob", in: knob)
        } else if isHovered && !isSoon {
          RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.hover)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isSoon)
    .onHover { hovering in
      isHovered = hovering
      // Not there yet: say so with the cursor, not just the tag.
      if isSoon {
        if hovering { NSCursor.operationNotAllowed.push() } else { NSCursor.pop() }
      }
    }
    .onDisappear {
      // Leaving the pane while over a "soon" app must not leave its cursor behind.
      if isSoon && isHovered { NSCursor.pop() }
    }
    .help(segment.title)
    .accessibilityLabel(segment.title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// What the protected chats below the open ones are filtered by.
private enum ChatFilter: Hashable {
  case all
  case app(Messenger)
}

// MARK: Protect the open chat

private struct ProtectNowSection: View {
  let model: SettingsModel

  var body: some View {
    Section {
      if model.openChats.isEmpty {
        SettingLabel(
          title: model.runningMessengers.isEmpty
            ? String(
              localized: "Open WhatsApp or Slack; the open chat shows up here.",
              bundle: .localization, comment: "Chats pane, when neither messenger is running.")
            : String(
              localized: "Open a chat in WhatsApp or Slack; it shows up here.",
              bundle: .localization, comment: "Chats pane, when no chat is open."),
          symbol: "arrow.up.forward.app"
        )
        .foregroundStyle(.secondary)
      } else {
        ForEach(model.openChats, id: \.self) { chat in
          LabeledContent {
            if model.guardedChats.isGuarded(chat) {
              Label(
                String(
                  localized: "Protected", bundle: .localization,
                  comment: "Chats pane: the open chat is already guarded."),
                systemImage: "checkmark"
              )
              .foregroundStyle(.secondary)
            } else if model.guardedChats.isAvailable(chat.messenger) {
              Button(
                model.guardedChats.isPaused(chat)
                  ? String(
                    localized: "Resume", bundle: .localization,
                    comment: "Chats pane button that resumes protecting a paused chat.")
                  : String(
                    localized: "Protect", bundle: .localization,
                    comment: "Chats pane button that guards an open chat.")
              ) { model.protect(chat) }
              .primaryButtonStyle(tint: chat.messenger.brandColor)
            } else {
              UnlockButton(tint: chat.messenger.brandColor) {
                model.requestAccess(to: chat.messenger)
              }
            }
          } label: {
            SettingLabel(
              title: chat.name.value, detail: chat.subtitle, symbol: nil,
              glyph: chat.messenger.glyph
            )
            .lineLimit(1)
          }
        }
      }
    } header: {
      Text(
        String(
          localized: "Open right now", bundle: .localization,
          comment: "Chats pane section: chats currently open in WhatsApp or Slack."))
    } footer: {
      Text(
        String(
          localized:
            "Welp protects the chat that’s open in WhatsApp or Slack. Open a chat there, then protect it here.",
          bundle: .localization,
          comment: "Chats pane: how protecting works, under the open chats."))
    }
  }
}

// MARK: Protected chats, per app

private struct AppSection<Prefix: View>: View {
  let model: SettingsModel
  let messenger: Messenger
  /// Shown above the app's name in the header (the filter, for the first section).
  @ViewBuilder let prefix: Prefix

  var body: some View {
    let chats = model.guardedChats.chats.filter { $0.id.messenger == messenger }
    let isAvailable = model.guardedChats.isAvailable(messenger)
    Section {
      if chats.isEmpty {
        LabeledContent {
          // An app this plan doesn't include: the way to get it, right where it's missing.
          if !isAvailable {
            UnlockButton(tint: messenger.brandColor) { model.requestAccess(to: messenger) }
          }
        } label: {
          Text(
            String(
              localized: "No \(messenger.displayName) chats protected yet.",
              bundle: .localization,
              comment:
                "Chats pane, an app with no guarded chats. The argument is WhatsApp or Slack.")
          )
          .foregroundStyle(.secondary)
          .padding(.vertical, 5)
        }
      } else {
        ForEach(chats, id: \.id) { chat in
          GuardedChatRow(model: model, chat: chat)
        }
      }
    } header: {
      VStack(alignment: .leading, spacing: 0) {
        prefix
        AppHeader(
          name: messenger.displayName,
          icon: AppIcon(
            bundleIdentifier: model.bundleIdentifier(of: messenger), glyph: messenger.glyph)
        ) {
          if !chats.isEmpty {
            Text(
              String(
                localized: "\(chats.count) chats", bundle: .localization,
                comment: "Settings sidebar: number of guarded chats.")
            )
            .foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

private struct GuardedChatRow: View {
  let model: SettingsModel
  let chat: GuardedChat

  var body: some View {
    let isAvailable = model.guardedChats.isAvailable(chat.id.messenger)
    LabeledContent {
      HStack(spacing: 10) {
        if isAvailable {
          Picker(
            String(
              localized: "Protection", bundle: .localization,
              comment: "Accessibility label of a guarded chat's protection mode picker."),
            selection: Binding(get: { chat.mode }, set: { model.setMode($0, for: chat.id) })
          ) {
            ForEach(ProtectionMode.allCases, id: \.self) { mode in
              Label(mode.shortTitle, systemImage: mode.symbol).tag(mode)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .fixedSize()
          .disabled(chat.isPaused)
          // On: guarded. Off: paused, kept with its mode until switched back on.
          Toggle(
            String(
              localized: "Pause or resume protecting this chat", bundle: .localization,
              comment: "Tooltip and accessibility label of a guarded chat's on/off switch."),
            isOn: Binding(
              get: { !chat.isPaused },
              set: { isOn in model.setPaused(!isOn, for: chat.id) })
          )
          .toggleStyle(.switch)
          .controlSize(.small)
          .labelsHidden()
          .help(
            String(
              localized: "Pause or resume protecting this chat", bundle: .localization,
              comment: "Tooltip and accessibility label of a guarded chat's on/off switch."))
        } else {
          // Saved, but this edition (or plan) can't guard its messenger right now.
          Text(
            String(
              localized: "Not protected", bundle: .localization,
              comment: "Chats pane: a saved chat whose app isn't available in this plan.")
          )
          .foregroundStyle(Theme.signal)
          UnlockButton(tint: chat.id.messenger.brandColor) {
            model.requestAccess(to: chat.id.messenger)
          }
        }
        // Deleting is one step away, behind the "more" menu, so it isn't hit by accident.
        Menu {
          Button(role: .destructive) {
            model.unguard(chat.id)
          } label: {
            Label(
              String(
                localized: "Delete", bundle: .localization,
                comment: "Menu item that removes a guarded chat from Welp."),
              systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis")
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(
          String(
            localized: "More", bundle: .localization,
            comment: "Tooltip of the menu with more actions for a guarded chat.")
        )
        .accessibilityLabel(
          String(
            localized: "More", bundle: .localization,
            comment: "Tooltip of the menu with more actions for a guarded chat."))
      }
    } label: {
      SettingLabel(
        title: chat.id.name.value,
        detail: chat.isPaused && isAvailable
          ? [
            chat.id.workspace?.value,
            String(
              localized: "Paused", bundle: .localization,
              comment: "Chats pane: a guarded chat that is switched off for now."),
          ].compactMap { $0 }.joined(separator: " · ")
          : chat.id.workspace?.value,
        symbol: nil, glyph: chat.id.messenger.glyph
      )
      .lineLimit(1)
      .opacity(chat.isPaused && isAvailable ? 0.55 : 1)
    }
  }
}

// MARK: Coming soon

/// Messengers Welp will support next. Not part of the domain model until they work.
private struct UpcomingApp: Identifiable {
  let name: String
  let bundleIdentifier: String
  /// The app's logo in `Resources/Glyphs`.
  let glyph: String
  /// The app's own color, for its calls to action once it is supported.
  let brandColor: Color
  var id: String { bundleIdentifier }

  static let all = [
    UpcomingApp(
      name: "Discord", bundleIdentifier: "com.hnc.Discord", glyph: "discord",
      brandColor: Color(nsColor: NSColor(hex: 0x5865F2))),
    UpcomingApp(
      name: "Teams", bundleIdentifier: "com.microsoft.teams2", glyph: "microsoftteams",
      brandColor: Color(nsColor: NSColor(hex: 0x7B83EB))),
  ]
}

// MARK: Shared pieces

/// For chats in a messenger the current plan doesn't include; asks the edition to unlock it.
private struct UnlockButton: View {
  let tint: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(
        String(
          localized: "Unlock", bundle: .localization,
          comment: "Chats pane button for an app that needs an upgrade to be protected."),
        systemImage: "lock.fill")
    }
    .primaryButtonStyle(tint: tint)
  }
}

extension SettingsModel {
  /// Whether the Chats pane lists `messenger`: WhatsApp always; others when this edition
  /// integrates them (even if the plan doesn't include them yet) or chats of it are saved.
  fileprivate func showsApp(_ messenger: Messenger) -> Bool {
    messenger == .whatsApp || bundleIdentifier(of: messenger) != nil
      || guardedChats.chats.contains { $0.id.messenger == messenger }
  }
}

/// A section header with the app's icon and name, and an optional trailing detail.
private struct AppHeader<Trailing: View>: View {
  let name: String
  let icon: AppIcon
  @ViewBuilder let trailing: Trailing

  var body: some View {
    HStack(spacing: 8) {
      icon
      Text(name)
      Spacer()
      trailing.font(.callout).fontWeight(.regular)
    }
  }
}

/// The app's own icon when it is installed, otherwise an SF Symbol in its place.
private struct AppIcon: View {
  let bundleIdentifier: String?
  let glyph: String

  var body: some View {
    if let url = bundleIdentifier.flatMap(
      NSWorkspace.shared.urlForApplication(withBundleIdentifier:))
    {
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        .resizable()
        .frame(width: 20, height: 20)
    } else {
      Image(nsImage: .appGlyph(glyph, size: 18))
        .renderingMode(.template)
        .foregroundStyle(.secondary)
        .frame(width: 20, height: 20)
    }
  }
}

extension NSImage {
  /// An SF Symbol for a segment of the app filter (a template, so it follows the text color).
  @MainActor
  fileprivate static func segmentSymbol(_ name: String) -> NSImage {
    let image =
      NSImage(systemSymbolName: name, accessibilityDescription: nil)?
      .withSymbolConfiguration(.init(pointSize: 12, weight: .regular)) ?? NSImage()
    image.isTemplate = true
    return image
  }

  /// A 16pt icon for a segment of the app filter: the app's own icon when it is installed,
  /// otherwise its one-color logo.
  @MainActor
  fileprivate static func segmentIcon(bundleIdentifier: String?, glyph: String) -> NSImage {
    let size = NSSize(width: 16, height: 16)
    if let url = bundleIdentifier.flatMap(
      NSWorkspace.shared.urlForApplication(withBundleIdentifier:)),
      let icon = NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage
    {
      icon.size = size
      return icon
    }
    return .appGlyph(glyph, size: 14)
  }
}

extension View {
  /// Calls `action` with this view's width, now and whenever it changes.
  fileprivate func onWidthChange(_ action: @escaping (CGFloat) -> Void) -> some View {
    background {
      GeometryReader { proxy in
        Color.clear.onChange(of: proxy.size.width, initial: true) { action($1) }
      }
    }
  }
}
