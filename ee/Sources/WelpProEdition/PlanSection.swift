import AppKit
import Licensing
import SwiftUI
import WelpApp

/// The General pane's plan section: Welp Free or Welp Pro, the subscription's state and the
/// license key. A native form section, like the rest of the settings.
struct PlanSection: View {
  let licenses: LicenseService
  @State private var key = ""
  @State private var error: String?

  var body: some View {
    Section {
      switch licenses.status {
      case .free:
        LabeledContent {
          Button(String.getWelpPro) { NSWorkspace.shared.open(Links.buyPro) }
            .primaryButtonStyle(tint: Color(nsColor: .systemBlue))
        } label: {
          SettingLabel(
            title: String(
              localized: "Welp Free", bundle: .welpPro, comment: "General pane plan name."),
            detail: String(
              localized:
                "Protects any number of WhatsApp chats. Welp Pro adds Slack, with Microsoft Teams and more on the way, for $9.99 a year.",
              bundle: .welpPro, comment: "General pane, free plan explanation."),
            symbol: "star")
        }
        licenseKeyField
      case .active(let license, _):
        proRow(
          detail: String(
            localized: "Licensed to \(license.email). WhatsApp and Slack are protected.",
            bundle: .welpPro, comment: "General pane, Pro plan. The argument is an email."),
          symbol: "star.fill")
      case .unconfirmed:
        proRow(detail: unconfirmedDetail, symbol: "star.leadinghalf.filled") {
          Button(
            String(
              localized: "Try Again", bundle: .welpPro,
              comment: "Button that checks the Welp Pro subscription with getwelp.io again.")
          ) { Task { await licenses.renew() } }
          .disabled(licenses.isRenewing)
        }
      case .ended:
        proRow(
          detail: String(
            localized:
              "Your Welp Pro subscription has ended, so Slack chats aren’t protected. WhatsApp still is.",
            bundle: .welpPro, comment: "General pane, Pro plan whose subscription has ended."),
          symbol: "star.slash"
        ) {
          Button(
            String(
              localized: "Renew", bundle: .welpPro,
              comment: "Button that opens the Welp Pro page to subscribe again.")
          ) { NSWorkspace.shared.open(Links.buyPro) }
          .primaryButtonStyle()
        }
        licenseKeyField
      }
    } header: {
      Text(
        String(
          localized: "Plan", bundle: .welpPro,
          comment: "General pane section: Welp Free or Welp Pro."))
    } footer: {
      if let error {
        Text(error).foregroundStyle(Theme.signal)
      } else {
        Text(
          String(
            localized:
              "The key is in your subscription email. About once a week, Welp sends it to getwelp.io, and nothing else, to check that your subscription is active.",
            bundle: .welpPro, comment: "Explanation under the plan section."))
      }
    }
  }

  private var unconfirmedDetail: String {
    if licenses.isRenewing {
      String(
        localized: "Checking your subscription…", bundle: .welpPro,
        comment: "General pane, while Welp checks the Pro subscription with getwelp.io.")
    } else if licenses.isUnreachable {
      String(
        localized:
          "Welp couldn’t reach getwelp.io to check your subscription. Slack chats are protected again once it can; WhatsApp still is.",
        bundle: .welpPro, comment: "General pane, Pro subscription can't be checked (offline).")
    } else {
      String(
        localized: "Your subscription needs to be checked with getwelp.io.", bundle: .welpPro,
        comment: "General pane, Pro subscription not checked yet.")
    }
  }

  private func proRow(
    detail: String, symbol: String, @ViewBuilder actions: () -> some View = { EmptyView() }
  ) -> some View {
    LabeledContent {
      HStack {
        actions()
        Button(
          String(
            localized: "Remove License", bundle: .welpPro,
            comment: "Button that removes the license key from this Mac.")
        ) { confirmRemoval() }
      }
    } label: {
      SettingLabel(
        title: String(
          localized: "Welp Pro", bundle: .welpPro, comment: "General pane plan name."),
        detail: detail, symbol: symbol)
    }
  }

  private var licenseKeyField: some View {
    HStack(spacing: 10) {
      Image(systemName: "key")
        .foregroundStyle(.secondary)
        .frame(width: 20)
      TextField(
        String(
          localized: "License key", bundle: .welpPro,
          comment: "Placeholder of the license key field."),
        text: $key,
        prompt: Text(
          String(
            localized: "License key", bundle: .welpPro,
            comment: "Placeholder of the license key field."))
      )
      .labelsHidden()
      .textFieldStyle(.roundedBorder)
      .onSubmit(activate)
      Button(
        String(
          localized: "Activate", bundle: .welpPro,
          comment: "Button that activates the license key typed next to it."),
        action: activate
      )
      .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || licenses.isRenewing)
    }
    .padding(.vertical, 5)
  }

  private func activate() {
    let entered = key
    Task {
      do throws(LicenseError) {
        try await licenses.activate(entered)
        key = ""
        error = nil
      } catch {
        self.error = Self.message(for: error)
      }
    }
  }

  /// Removing the key stops protecting Slack chats, so it is never done silently.
  private func confirmRemoval() {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = String(
      localized: "Remove the Welp Pro license from this Mac?", bundle: .welpPro,
      comment: "Confirmation title before removing the license key.")
    alert.informativeText = String(
      localized:
        "Your Slack chats stay in the list but won’t be protected until you enter a license key again. WhatsApp stays protected.",
      bundle: .welpPro, comment: "Confirmation text before removing the license key.")
    alert.addButton(
      withTitle: String(
        localized: "Cancel", bundle: .welpPro, comment: "Alert button; keeps the license."))
    alert.addButton(
      withTitle: String(
        localized: "Remove License", bundle: .welpPro,
        comment: "Button that removes the license key from this Mac."))
    if alert.runModal() == .alertSecondButtonReturn {
      licenses.remove()
    }
  }

  private static func message(for error: LicenseError) -> String {
    switch error {
    case .malformed:
      String(
        localized: "That doesn’t look like a Welp license key. Copy the whole key from the email.",
        bundle: .welpPro, comment: "License key error.")
    case .invalidSignature:
      String(
        localized: "This license key isn’t valid. Check that it was copied completely.",
        bundle: .welpPro, comment: "License key error.")
    case .unsupported:
      String(
        localized:
          "This license key doesn’t work with this version of Welp. Get your current key at getwelp.io/pro.",
        bundle: .welpPro, comment: "License key error.")
    }
  }
}
