import CoreGraphics

/// Finds which process owns the on-screen window under a point.
/// Uses the window server only, so it is fast and never blocks on another app.
public enum WindowOwnerLocator {
  public static func ownerPID(at point: CGPoint) -> pid_t? {
    guard
      let windows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]]
    else { return nil }

    // The list is ordered front to back.
    for window in windows {
      guard
        let boundsDictionary = window[kCGWindowBounds],
        let bounds = CGRect(dictionaryRepresentation: boundsDictionary as! CFDictionary),
        bounds.contains(point),
        (window[kCGWindowAlpha] as? Double ?? 1) > 0
      else { continue }
      return window[kCGWindowOwnerPID] as? pid_t
    }
    return nil
  }
}
