import Foundation

/// User-tunable timing of the guard.
public struct GuardBehavior: Sendable, Equatable {
  /// In "first message" mode, ask again after this much silence in the chat. `nil`: never.
  public var reaskAfterIdle: TimeInterval?
  /// In "undo" mode, how long a message is held before it is sent.
  public var undoDelay: TimeInterval

  public init(reaskAfterIdle: TimeInterval?, undoDelay: TimeInterval) {
    self.reaskAfterIdle = reaskAfterIdle
    self.undoDelay = undoDelay
  }
}
