/// Routes a gesture to the first messenger screen that recognises it.
@MainActor
public final class CompositeSendTargetScreen: SendTargetScreen {
  private let screens: [any SendTargetScreen]

  public init(_ screens: [any SendTargetScreen]) {
    self.screens = screens
  }

  public func sendTarget(for gesture: SendGesture) -> SendTarget? {
    for screen in screens {
      if let target = screen.sendTarget(for: gesture) { return target }
    }
    return nil
  }
}
