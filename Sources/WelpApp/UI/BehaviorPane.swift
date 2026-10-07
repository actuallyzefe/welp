import Preferences
import SharedKernel
import SwiftUI

struct BehaviorPane: View {
  let model: SettingsModel

  private var preferences: Preferences { model.preferences.current }

  var body: some View {
    Form {
      Section {
        Picker(
          String(
            localized: "Default for new chats", bundle: .localization,
            comment: "Behavior pane section."),
          selection: Binding(
            get: { preferences.defaultMode },
            set: { value in model.update { $0.defaultMode = value } })
        ) {
          ForEach(ProtectionMode.allCases, id: \.self) { mode in
            SettingLabel(
              title: mode == .default
                ? "\(mode.title) · "
                  + String(
                    localized: "Recommended", bundle: .localization,
                    comment: "Tag on the default protection mode.")
                : mode.title,
              detail: mode.explanation,
              symbol: mode.symbol
            )
            // The whole row selects the mode, not only the radio button.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { model.update { $0.defaultMode = mode } }
            .tag(mode)
          }
        }
        .pickerStyle(.radioGroup)
        .labelsHidden()
      } header: {
        Text(
          String(
            localized: "Default for new chats", bundle: .localization,
            comment: "Behavior pane section."))
      } footer: {
        Text(
          String(
            localized: "You can change each chat’s mode separately under “Chats”.",
            bundle: .localization,
            comment: "Behavior pane hint. “Chats” is the settings section name."))
      }

      Section(ProtectionMode.firstMessage.title) {
        Toggle(
          isOn: Binding(
            get: { preferences.reasksAfterIdle },
            set: { value in model.update { $0.reasksAfterIdle = value } })
        ) {
          SettingLabel(
            title: String(
              localized: "Ask again after silence", bundle: .localization,
              comment: "Behavior setting."),
            detail: String(
              localized: "If you don’t send anything for a while, asks again on the next message.",
              bundle: .localization, comment: "Behavior setting explanation."),
            symbol: "moon.zzz")
        }
        Picker(
          selection: Binding(
            get: { preferences.idleMinutes },
            set: { value in model.update { $0.idleMinutes = value } })
        ) {
          ForEach(Preferences.idleMinuteOptions, id: \.self) { minutes in
            Text(Duration.seconds(minutes * 60).formatted(.minutes)).tag(minutes)
          }
        } label: {
          SettingLabel(
            title: String(
              localized: "Duration", bundle: .localization,
              comment: "Behavior setting: silence before asking again."),
            detail: String(
              localized: "Welp asks again after this much silence.", bundle: .localization,
              comment: "Behavior setting explanation."),
            symbol: "timer")
        }
        .pickerStyle(.menu)
        .disabled(!preferences.reasksAfterIdle)
      }

      Section(ProtectionMode.undo.title) {
        Picker(
          selection: Binding(
            get: { preferences.undoSeconds },
            set: { value in model.update { $0.undoSeconds = value } })
        ) {
          ForEach(Preferences.undoSecondOptions, id: \.self) { seconds in
            Text(Duration.seconds(seconds).formatted(.seconds)).tag(seconds)
          }
        } label: {
          SettingLabel(
            title: String(
              localized: "Hold time", bundle: .localization,
              comment: "Behavior setting for the Undo mode."),
            detail: String(
              localized: "The message is held this long; you can press “Undo” in the meantime.",
              bundle: .localization, comment: "Behavior setting explanation."),
            symbol: "hourglass")
        }
        .pickerStyle(.menu)
      }
    }
    .formStyle(.grouped)
  }
}

extension FormatStyle where Self == Duration.UnitsFormatStyle {
  /// "15 min" / "15 dk", following the UI language.
  fileprivate static var minutes: Self { .units(allowed: [.minutes], width: .abbreviated) }
  /// "5 sec" / "5 sn", following the UI language.
  fileprivate static var seconds: Self { .units(allowed: [.seconds], width: .abbreviated) }
}
