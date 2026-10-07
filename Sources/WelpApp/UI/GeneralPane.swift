import SwiftUI

struct GeneralPane: View {
  let model: SettingsModel

  var body: some View {
    Form {
      Section(
        String(localized: "Permission", bundle: .localization, comment: "General pane section.")
      ) {
        PermissionRow(model: model)
      }

      // The edition's plan and license key (Welp Pro), if it has one.
      if let plan = model.edition.planSection() {
        plan
      }

      Section(
        String(localized: "Startup", bundle: .localization, comment: "General pane section.")
      ) {
        Toggle(
          isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchesAtLogin($0) })
        ) {
          SettingLabel(
            title: String(
              localized: "Open at login", bundle: .localization, comment: "General setting."),
            detail: String(
              localized: "Welp quietly starts in the menu bar.", bundle: .localization,
              comment: "General setting explanation."),
            symbol: "power")
        }
      }

      LanguageSection(model: model)

      if let updater = model.edition.updater {
        UpdatesSection(updater: updater)
      }

      Section {
        SettingLabel(
          title: String(
            localized: "Everything stays on this Mac", bundle: .localization,
            comment: "General pane privacy note title."),
          detail: model.edition.updater == nil
            ? String(
              localized:
                "Welp doesn’t connect to the internet. What you write is never saved, logged or sent anywhere; Welp only looks at a message at the moment you send it, to protect it.",
              bundle: .localization, comment: "General pane privacy note.")
            : String(
              localized:
                "Welp only connects to the internet to check for updates, if you allow it, and, with Welp Pro, to confirm your subscription about once a week by sending only your license key. What you write is never saved, logged or sent anywhere; Welp only looks at a message at the moment you send it, to protect it.",
              bundle: .localization,
              comment: "General pane privacy note, in builds that can check for updates."),
          symbol: "lock")
      } header: {
        Text(String(localized: "Privacy", bundle: .localization, comment: "General pane section."))
      } footer: {
        Text(verbatim: "Welp \(Self.version)")
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .formStyle(.grouped)
  }

  static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
  }
}

private struct PermissionRow: View {
  let model: SettingsModel

  var body: some View {
    let granted = model.isPermissionGranted
    LabeledContent {
      if !granted {
        Button(
          String(
            localized: "Open Settings", bundle: .localization,
            comment: "Button that opens System Settings › Accessibility.")
        ) { model.openPermissionSettings() }
        .primaryButtonStyle()
      }
    } label: {
      SettingLabel(
        title: granted
          ? String(
            localized: "Accessibility permission granted", bundle: .localization,
            comment: "General pane permission status.")
          : String(
            localized: "Accessibility permission required", bundle: .localization,
            comment: "General pane permission status."),
        detail: granted
          ? String(
            localized: "Welp can see the send button in WhatsApp and Slack.",
            bundle: .localization, comment: "General pane permission explanation.")
          : String(
            localized: "Allow it in System Settings so Welp can see your sends.",
            bundle: .localization, comment: "General pane permission explanation."),
        symbol: granted ? "checkmark.shield" : "exclamationmark.triangle.fill",
        symbolStyle: granted ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.signal))
    }
  }
}

private struct LanguageSection: View {
  let model: SettingsModel

  var body: some View {
    Section(
      String(localized: "Language", bundle: .localization, comment: "General pane section.")
    ) {
      Picker(selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
        Text(
          String(
            localized: "System Language", bundle: .localization,
            comment: "Language picker option: use the Mac's language.")
        )
        .tag(String?.none)
        Divider()
        ForEach(model.languageSetting.available, id: \.self) { language in
          Text(LanguageSetting.displayName(of: language)).tag(Optional(language))
        }
      } label: {
        SettingLabel(
          title: String(
            localized: "Language", bundle: .localization,
            comment: "General setting: the app's interface language."),
          detail: String(
            localized:
              "The language of Welp’s menus and windows. “System Language” follows your Mac.",
            bundle: .localization,
            comment:
              "General setting explanation. “System Language” is the first option of the picker."),
          symbol: "globe")
      }
      .pickerStyle(.menu)

      if model.languageNeedsRelaunch {
        LabeledContent {
          Button(
            String(
              localized: "Restart Welp", bundle: .localization,
              comment: "Button that quits and reopens the app.")
          ) { model.relaunch() }
          .primaryButtonStyle()
        } label: {
          SettingLabel(
            title: String(
              localized: "Restart to apply", bundle: .localization,
              comment: "Shown after choosing another language."),
            detail: String(
              localized:
                "Welp closes and opens again in the new language. Protection pauses for a moment.",
              bundle: .localization,
              comment: "Explanation of the restart needed for a new language."),
            symbol: "arrow.clockwise")
        }
      }
    }
  }
}

private struct UpdatesSection: View {
  let updater: any AppUpdater
  @State private var automaticallyChecks: Bool

  init(updater: any AppUpdater) {
    self.updater = updater
    _automaticallyChecks = State(initialValue: updater.automaticallyChecksForUpdates)
  }

  var body: some View {
    Section(
      String(localized: "Updates", bundle: .localization, comment: "General pane section.")
    ) {
      Toggle(
        isOn: Binding(
          get: { automaticallyChecks },
          set: {
            automaticallyChecks = $0
            updater.automaticallyChecksForUpdates = $0
          })
      ) {
        SettingLabel(
          title: String(
            localized: "Check for updates automatically", bundle: .localization,
            comment: "General setting."),
          detail: String(
            localized:
              "About once a day Welp asks getwelp.io for a newer version and offers to install it. Nothing about you or your chats is sent.",
            bundle: .localization, comment: "General setting explanation."),
          symbol: "arrow.triangle.2.circlepath")
      }
      LabeledContent {
        Button(String.checkForUpdates) { updater.checkForUpdates() }
      } label: {
        SettingLabel(
          title: String(
            localized: "Check now", bundle: .localization,
            comment: "General setting: check for a newer version right away."),
          detail: String(
            localized: "Welp \(GeneralPane.version)", bundle: .localization,
            comment: "Current version under Check now. The argument is the version number."),
          symbol: "sparkles")
      }
    }
  }
}

extension String {
  static var checkForUpdates: String {
    String(
      localized: "Check for Updates…", bundle: .localization,
      comment: "Button and menu item that checks for a newer version of Welp.")
  }
}
