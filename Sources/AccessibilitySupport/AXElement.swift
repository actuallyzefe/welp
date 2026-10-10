import ApplicationServices
import Foundation

/// Thin, typed wrapper over `AXUIElement`.
public struct AXElement {
  public let raw: AXUIElement

  public init(raw: AXUIElement) {
    self.raw = raw
  }

  public static var systemWide: AXElement { AXElement(raw: AXUIElementCreateSystemWide()) }

  public static func application(_ pid: pid_t) -> AXElement {
    AXElement(raw: AXUIElementCreateApplication(pid))
  }

  // MARK: Attributes

  public var role: String? { string(kAXRoleAttribute) }
  public var subrole: String? { string(kAXSubroleAttribute) }
  public var identifier: String? { string(kAXIdentifierAttribute) }
  public var label: String? { string(kAXDescriptionAttribute) }
  public var value: String? { string(kAXValueAttribute) }

  public var parent: AXElement? { element(kAXParentAttribute) }
  public var window: AXElement? { element(kAXWindowAttribute) }
  public var focusedElement: AXElement? { element(kAXFocusedUIElementAttribute) }
  public var mainWindow: AXElement? {
    element(kAXMainWindowAttribute) ?? element(kAXFocusedWindowAttribute)
  }

  public var title: String? { string(kAXTitleAttribute) }
  /// The address of a document, e.g. the page a web area shows.
  public var url: URL? { attribute(kAXURLAttribute) as? URL }

  /// On-screen frame in global, top-left-origin coordinates.
  public var frame: CGRect? {
    guard let position = axValue(kAXPositionAttribute), let size = axValue(kAXSizeAttribute)
    else { return nil }
    var origin = CGPoint.zero
    var extent = CGSize.zero
    guard AXValueGetValue(position, .cgPoint, &origin), AXValueGetValue(size, .cgSize, &extent)
    else { return nil }
    return CGRect(origin: origin, size: extent)
  }
  /// CSS classes of web content (Chromium / Electron apps).
  public var classList: [String] { attribute("AXDOMClassList") as? [String] ?? [] }

  public func hasClass(_ name: String) -> Bool {
    classList.contains(name)
  }

  public var children: [AXElement] {
    (attribute(kAXChildrenAttribute) as? [AXUIElement] ?? []).map(AXElement.init)
  }

  // MARK: Queries

  public func element(at point: CGPoint) -> AXElement? {
    var hit: AXUIElement?
    guard AXUIElementCopyElementAtPosition(raw, Float(point.x), Float(point.y), &hit) == .success
    else { return nil }
    return hit.map(AXElement.init)
  }

  /// Breadth-first search, bounded in nodes and in time so a huge or busy UI can never stall
  /// an event tap: an app that answers each call just under the timeout would otherwise keep
  /// a search of a few hundred nodes going for many seconds.
  public func firstDescendant(
    maxNodes: Int = 2_000, within budget: Duration = .milliseconds(250),
    where matches: (AXElement) -> Bool
  ) -> AXElement? {
    let clock = ContinuousClock()
    let deadline = clock.now + budget
    var queue = children
    var visited = 0
    while !queue.isEmpty, visited < maxNodes, clock.now < deadline {
      let next = queue.removeFirst()
      visited += 1
      if matches(next) { return next }
      queue.append(contentsOf: next.children)
    }
    return nil
  }

  public func selfOrAncestor(maxDepth: Int, where matches: (AXElement) -> Bool) -> AXElement? {
    var current: AXElement? = self
    for _ in 0...maxDepth {
      guard let element = current else { return nil }
      if matches(element) { return element }
      current = element.parent
    }
    return nil
  }

  // MARK: Actions

  @discardableResult
  public func press() -> Bool {
    AXUIElementPerformAction(raw, kAXPressAction as CFString) == .success
  }

  /// Bounds every Accessibility call this process makes, to any app.
  ///
  /// A timeout set on one element applies to that element only, not to the windows and
  /// children read from it, so it has to be set for the whole process. Otherwise a messenger
  /// busy redrawing after an app switch holds the main thread, where the event tap runs, for
  /// the system default of several seconds; macOS then disables the tap and the held Return
  /// reaches the messenger unchecked.
  public static func limitMessagingTimeout(to seconds: Float) {
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), seconds)
  }

  @discardableResult
  public func setFlag(_ attribute: String, _ value: Bool) -> Bool {
    let flag: CFBoolean = value ? kCFBooleanTrue : kCFBooleanFalse
    return AXUIElementSetAttributeValue(raw, attribute as CFString, flag) == .success
  }

  // MARK: Private

  private func attribute(_ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(raw, name as CFString, &value) == .success else {
      return nil
    }
    return value
  }

  private func axValue(_ name: String) -> AXValue? {
    guard let value = attribute(name), CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }
    return unsafeDowncast(value, to: AXValue.self)
  }

  private func string(_ name: String) -> String? {
    attribute(name) as? String
  }

  private func element(_ name: String) -> AXElement? {
    guard let value = attribute(name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    return AXElement(raw: unsafeDowncast(value, to: AXUIElement.self))
  }
}
