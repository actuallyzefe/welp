/// Logging port. The app provides an `os.Logger`-backed implementation.
public protocol AppLogger: Sendable {
  func debug(_ message: String)
  func info(_ message: String)
  func warning(_ message: String)
  func error(_ message: String)
}

/// Discards everything; handy for tests.
public struct NullLogger: AppLogger {
  public init() {}
  public func debug(_ message: String) {}
  public func info(_ message: String) {}
  public func warning(_ message: String) {}
  public func error(_ message: String) {}
}
