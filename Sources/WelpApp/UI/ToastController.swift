import AppKit
import SendGuard
import SharedKernel
import SwiftUI

/// Non-blocking cards right above the chat's message box (the screen's top-right corner if it
/// can't be found): the "Undo" countdown and notices. They never take focus, so typing in the
/// messenger continues undisturbed.
@MainActor
final class ToastController: SendFeedback {
  private static let noticeDuration: Duration = .seconds(3)
  /// Longer when there is a button, so there is time to read the notice and decide.
  private static let actionableNoticeDuration: Duration = .seconds(8)

  private let panel = OverlayPanel.make(interactive: true)
  private var dismissal: Task<Void, Never>?
  /// Bumped by every toast, so a fade-out that finishes late cannot hide its successor.
  private var generation = 0
  /// Ends the "Undo" countdown on screen, if one is.
  private var finishUndoCountdown: (@MainActor (UndoOutcome) -> Void)?
  private let anchor: ComposerAnchor

  init(anchor: ComposerAnchor) {
    self.anchor = anchor
  }

  func offerUndo(
    for attempt: SendAttempt, seconds: TimeInterval,
    completion: @escaping @MainActor (UndoOutcome) -> Void
  ) {
    var finished = false
    let finish: @MainActor (UndoOutcome) -> Void = { [weak self] outcome in
      guard !finished else { return }
      finished = true
      self?.finishUndoCountdown = nil
      self?.hide()
      completion(outcome)
    }
    finishUndoCountdown = finish

    present(
      UndoCard(
        attempt: attempt,
        seconds: seconds,
        onUndo: { finish(.undo) },
        onSendNow: { finish(.send) }
      ))
    dismissal = Task { @MainActor in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      finish(.send)
    }
  }

  func finishUndo(_ outcome: UndoOutcome) {
    finishUndoCountdown?(outcome)
  }

  func notify(_ notice: SendNotice, returnAndSend: (@MainActor () -> Void)?) {
    present(
      NoticeCard(
        notice: notice,
        returnAndSend: returnAndSend.map { action in
          { [weak self] in
            self?.hide()
            action()
          }
        }))
    let duration = returnAndSend == nil ? Self.noticeDuration : Self.actionableNoticeDuration
    dismissal = Task { @MainActor [weak self] in
      try? await Task.sleep(for: duration)
      guard !Task.isCancelled else { return }
      self?.hide()
    }
  }

  private func present<V: View>(_ view: V) {
    dismissal?.cancel()
    generation += 1
    let host = FirstClickHostingView(rootView: view)
    panel.contentView = host
    panel.setFrame(
      anchor.frame(for: host.fittingSize, inset: SendPromptLayout.inset, fallback: .topRight),
      display: true)
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.18
      panel.animator().alphaValue = 1
    }
  }

  private func hide() {
    dismissal?.cancel()
    dismissal = nil
    let hidden = generation
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.18
        panel.animator().alphaValue = 0
      },
      completionHandler: { [weak self] in
        MainActor.assumeIsolated {
          guard let self, self.generation == hidden else { return }
          self.panel.orderOut(nil)
        }
      })
  }
}
