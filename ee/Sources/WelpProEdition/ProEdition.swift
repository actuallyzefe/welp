import Licensing
import SharedKernel
import SlackAccessibility
import SwiftUI
import WelpApp

extension SlackScreen: MessengerScreen {}

/// The official Welp app: the open-source core plus Welp Pro. Without a license it works
/// exactly like the core (WhatsApp); a Welp Pro subscription adds Slack.
@MainActor
public final class ProEdition: WelpEdition {
  /// Messengers that need Welp Pro. WhatsApp is the core's and always free.
  static let proMessengers: Set<Messenger> = [.slack]

  let licenses: LicenseService

  /// The official app: keeps the subscription's lease fresh for as long as it runs.
  public convenience init() {
    self.init(licenses: LicenseService(store: UserDefaultsLicenseStore()))
    Task { [licenses] in await licenses.keepRenewing() }
  }

  init(licenses: LicenseService) {
    self.licenses = licenses
  }

  public func makeScreens(postReturnKey: @escaping @MainActor (_ withCommand: Bool) -> Void)
    -> [any MessengerScreen]
  {
    [SlackScreen(postReturnKey: postReturnKey)]
  }

  public func isAvailable(_ messenger: Messenger) -> Bool {
    Self.proMessengers.contains(messenger) && licenses.isPro
  }

  public func requestAccess(to messenger: Messenger, openPlan: @escaping @MainActor () -> Void) {
    UpgradePrompt.show(for: messenger, openPlan: openPlan)
  }

  /// Created on first use, once the app has launched (Sparkle needs a running app).
  public private(set) lazy var updater: (any AppUpdater)? =
    SparkleUpdater.isConfigured ? SparkleUpdater() : nil

  public func planSection() -> AnyView? {
    AnyView(PlanSection(licenses: licenses))
  }
}
