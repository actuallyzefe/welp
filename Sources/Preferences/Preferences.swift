import SharedKernel

/// App-wide settings.
public struct Preferences: Codable, Equatable, Sendable {
  public static let idleMinuteOptions = [5, 15, 30, 60]
  public static let undoSecondOptions = [3, 5, 10]

  /// Mode given to chats guarded from now on.
  public var defaultMode: ProtectionMode
  /// "First message" mode: ask again after `idleMinutes` without sending.
  public var reasksAfterIdle: Bool
  public var idleMinutes: Int
  /// "Undo" mode: how long a message is held.
  public var undoSeconds: Int
  /// Badge above the message box while in a guarded chat.
  public var showsComposerBadge: Bool
  /// Red menu bar shield while in a guarded chat.
  public var tintsMenuBarIcon: Bool

  public static let standard = Preferences(
    defaultMode: .default,
    reasksAfterIdle: true,
    idleMinutes: 15,
    undoSeconds: 5,
    showsComposerBadge: true,
    tintsMenuBarIcon: true
  )

  public init(
    defaultMode: ProtectionMode, reasksAfterIdle: Bool, idleMinutes: Int, undoSeconds: Int,
    showsComposerBadge: Bool, tintsMenuBarIcon: Bool
  ) {
    self.defaultMode = defaultMode
    self.reasksAfterIdle = reasksAfterIdle
    self.idleMinutes = idleMinutes
    self.undoSeconds = undoSeconds
    self.showsComposerBadge = showsComposerBadge
    self.tintsMenuBarIcon = tintsMenuBarIcon
  }

  /// Tolerates missing keys, so settings saved by older versions keep working.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let fallback = Self.standard
    defaultMode =
      try container.decodeIfPresent(ProtectionMode.self, forKey: .defaultMode)
      ?? fallback.defaultMode
    reasksAfterIdle =
      try container.decodeIfPresent(Bool.self, forKey: .reasksAfterIdle)
      ?? fallback.reasksAfterIdle
    idleMinutes =
      try container.decodeIfPresent(Int.self, forKey: .idleMinutes)
      ?? fallback.idleMinutes
    undoSeconds =
      try container.decodeIfPresent(Int.self, forKey: .undoSeconds)
      ?? fallback.undoSeconds
    showsComposerBadge =
      try container.decodeIfPresent(Bool.self, forKey: .showsComposerBadge)
      ?? fallback.showsComposerBadge
    tintsMenuBarIcon =
      try container.decodeIfPresent(Bool.self, forKey: .tintsMenuBarIcon)
      ?? fallback.tintsMenuBarIcon
  }
}
