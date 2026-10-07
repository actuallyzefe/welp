import CoreGraphics

/// A user input that may send a message.
public enum InputGesture: Sendable, Equatable {
  /// Return / Enter, optionally with ⌘ or ⌃ (Slack's send shortcut in "newline" mode).
  /// `targetProcess` is the process the window server routes the key to.
  case returnKey(withCommand: Bool, targetProcess: pid_t)
  case click(at: CGPoint)
  /// Escape: never a send, but it can stop a held one.
  case escapeKey
}

public enum InputVerdict: Sendable, Equatable {
  case pass
  case swallow
}

public enum InputInterceptionError: Error, Equatable {
  /// Usually means the Accessibility permission has not been granted.
  case eventTapUnavailable
}

/// Session-wide event tap that lets a handler swallow Return presses and clicks
/// before any application sees them.
///
/// The tap sits at the *annotated* session level, where the window server has already
/// decided which process receives each event. That is the only reliable answer to
/// "where does this key go?": launchers such as Raycast or Spotlight take keyboard focus
/// with non-activating panels, so the frontmost app is not necessarily the key target.
///
/// The handler runs synchronously on the main thread for every relevant event and
/// must return quickly; macOS disables slow taps.
@MainActor
public final class InputInterceptor {
  /// Tags events we post ourselves so the tap lets them through.
  static let syntheticEventMarker: Int64 = 0x5745_4C50  // "WELP"

  private static let returnKeyCodes: Set<Int64> = [36, 76]  // Return, keypad Enter
  private static let escapeKeyCode: Int64 = 53
  /// Return with these held inserts a new line; never a send.
  private static let newlineModifiers: CGEventFlags = [.maskShift, .maskAlternate]
  private static let commandModifiers: CGEventFlags = [.maskCommand, .maskControl]

  private let handler: @MainActor (InputGesture) -> InputVerdict
  private var tap: CFMachPort?
  private var swallowNextMouseUp = false

  public init(handler: @escaping @MainActor (InputGesture) -> InputVerdict) {
    self.handler = handler
  }

  public var isRunning: Bool { tap != nil }

  public func start() throws {
    guard tap == nil else { return }

    let events: [CGEventType] = [.keyDown, .leftMouseDown, .leftMouseUp]
    let mask = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgAnnotatedSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: inputInterceptorCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else { throw InputInterceptionError.eventTapUnavailable }

    // Common modes include the modal panel mode, so input keeps flowing while our
    // own confirmation alert is on screen.
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    self.tap = tap
  }

  /// Posts a Return key press (optionally with ⌘) that bypasses the interceptor.
  public static func postReturnKey(withCommand: Bool) {
    let source = CGEventSource(stateID: .hidSystemState)
    for isKeyDown in [true, false] {
      let event = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: isKeyDown)
      event?.flags = withCommand ? .maskCommand : []
      event?.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
      event?.post(tap: .cghidEventTap)
    }
  }

  fileprivate func shouldSwallow(_ type: CGEventType, _ event: EventSnapshot) -> Bool {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return false

    case .keyDown:
      if event.keyCode == Self.escapeKeyCode, !isSynthetic(event) {
        return handler(.escapeKey) == .swallow
      }
      guard isSendableReturn(event) else { return false }
      let withCommand = !event.flags.intersection(Self.commandModifiers).isEmpty
      let gesture = InputGesture.returnKey(
        withCommand: withCommand, targetProcess: event.targetProcess)
      return handler(gesture) == .swallow

    case .leftMouseDown:
      guard !isSynthetic(event) else { return false }
      swallowNextMouseUp = handler(.click(at: event.location)) == .swallow
      return swallowNextMouseUp

    case .leftMouseUp:
      // Never deliver half a click.
      defer { swallowNextMouseUp = false }
      return swallowNextMouseUp

    default:
      return false
    }
  }

  private func isSendableReturn(_ event: EventSnapshot) -> Bool {
    Self.returnKeyCodes.contains(event.keyCode)
      && event.flags.intersection(Self.newlineModifiers).isEmpty
      && !isSynthetic(event)
  }

  private func isSynthetic(_ event: EventSnapshot) -> Bool {
    event.sourceUserData == Self.syntheticEventMarker
  }
}

/// The parts of a `CGEvent` we need, copied out so they can cross into the main actor.
struct EventSnapshot: Sendable {
  let keyCode: Int64
  let flags: CGEventFlags
  let location: CGPoint
  let sourceUserData: Int64
  /// Receiving process, as annotated by the window server.
  let targetProcess: pid_t

  init(_ event: CGEvent) {
    keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    flags = event.flags
    location = event.location
    sourceUserData = event.getIntegerValueField(.eventSourceUserData)
    targetProcess = pid_t(truncatingIfNeeded: event.getIntegerValueField(.eventTargetUnixProcessID))
  }
}

/// C callback; the tap's run loop source lives on the main run loop.
private func inputInterceptorCallback(
  proxy: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let userInfo else { return Unmanaged.passUnretained(event) }
  let interceptor = Unmanaged<InputInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
  let snapshot = EventSnapshot(event)
  let swallow = MainActor.assumeIsolated { interceptor.shouldSwallow(type, snapshot) }
  return swallow ? nil : Unmanaged.passUnretained(event)
}
