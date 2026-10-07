import SharedKernel

/// A chat that requires confirmation before sending, and how.
public struct GuardedChat: Equatable, Sendable, Identifiable {
  public let id: ChatID
  public var mode: ProtectionMode
  /// Kept in the list with its mode, but not guarded until resumed.
  public var isPaused: Bool

  public init(id: ChatID, mode: ProtectionMode, isPaused: Bool = false) {
    self.id = id
    self.mode = mode
    self.isPaused = isPaused
  }
}
