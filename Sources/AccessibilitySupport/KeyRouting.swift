import AppKit

extension NSRunningApplication {
  /// Whether a key event the window server routed to `targetProcess` reaches this app.
  ///
  /// Being frontmost is not enough: launchers such as Raycast or Spotlight take keyboard
  /// focus with non-activating panels while another app stays frontmost. `0` means the
  /// event carried no routing annotation; only then is "frontmost" used as a fallback.
  public func receivesKeys(routedTo targetProcess: pid_t) -> Bool {
    targetProcess == 0 ? isActive : targetProcess == processIdentifier
  }
}
