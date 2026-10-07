import Preferences
import SharedKernel
import SwiftUI

struct AppearancePane: View {
  let model: SettingsModel

  private var preferences: Preferences { model.preferences.current }

  var body: some View {
    Form {
      Section(
        String(
          localized: "Message box badge", bundle: .localization,
          comment: "Appearance pane section.")
      ) {
        Toggle(isOn: binding(\.showsComposerBadge)) {
          SettingLabel.welp(
            title: String(
              localized: "Show the badge", bundle: .localization, comment: "Appearance setting."),
            detail: String(
              localized:
                "Sits above the message box while you’re in a guarded chat. Doesn’t block clicks.",
              bundle: .localization, comment: "Appearance setting explanation."))
        }
        ComposerPreview(isEnabled: preferences.showsComposerBadge)
      }

      Section(
        String(localized: "Menu bar", bundle: .localization, comment: "Appearance pane section.")
      ) {
        Toggle(isOn: binding(\.tintsMenuBarIcon)) {
          SettingLabel.welp(
            title: String(
              localized: "Turn the icon red", bundle: .localization,
              comment: "Appearance setting: the menu bar icon turns red in a guarded chat."),
            detail: String(
              localized: "Changes the color of the menu bar icon while you’re in a guarded chat.",
              bundle: .localization, comment: "Appearance setting explanation."))
        }
        MenuBarPreview(isEnabled: preferences.tintsMenuBarIcon)
      }
    }
    .formStyle(.grouped)
  }

  private func binding(_ keyPath: WritableKeyPath<Preferences, Bool>) -> Binding<Bool> {
    Binding(
      get: { preferences[keyPath: keyPath] },
      set: { value in model.update { $0[keyPath: keyPath] = value } }
    )
  }
}

extension String {
  /// A made-up chat for previews and screenshots.
  static var sampleChatName: String {
    String(
      localized: "Acme Customer", bundle: .localization,
      comment: "Made-up chat name shown in previews.")
  }
}

/// An illustration of a messenger's message box with the badge above it.
private struct ComposerPreview: View {
  let isEnabled: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      GuardBadge(chatName: .sampleChatName, mode: .firstMessage)
        .opacity(isEnabled ? 1 : 0)
        .scaleEffect(isEnabled ? 1 : 0.9, anchor: .bottomLeading)
      HStack {
        Text(
          String(
            localized: "Type a message", bundle: .localization,
            comment: "Placeholder in the preview of a messenger’s message box.")
        )
        .foregroundStyle(.tertiary)
        Spacer()
        Image(systemName: "paperplane.fill").foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 14)
      .frame(height: 36)
      .background(.quaternary, in: Capsule())
    }
    .padding(.vertical, 8)
    .animation(.default, value: isEnabled)
  }
}

/// An illustration of the menu bar icon in a regular and a guarded chat.
private struct MenuBarPreview: View {
  let isEnabled: Bool

  var body: some View {
    HStack(spacing: 24) {
      item(
        tint: nil,
        caption: String(
          localized: "Regular chat", bundle: .localization,
          comment: "Caption in the menu bar icon preview."))
      item(
        tint: isEnabled ? Theme.signal : nil,
        caption: String(
          localized: "Guarded chat", bundle: .localization,
          comment: "Caption in the menu bar icon preview."))
      Spacer()
    }
    .padding(.vertical, 8)
    .animation(.default, value: isEnabled)
  }

  private func item(tint: Color?, caption: String) -> some View {
    Label {
      Text(caption).foregroundStyle(.secondary)
    } icon: {
      WelpMark()
        .frame(height: 15)
        .foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
    }
  }
}
