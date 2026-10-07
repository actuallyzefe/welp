import Foundation
import SharedKernel

/// Remembers "first message" approvals for the chat you are currently in.
///
/// An approval lasts while you stay in that chat. It ends when you open another chat
/// (per messenger) or, optionally, after a period without sending anything.
@MainActor
public final class ApprovalMemory {
  private struct Visit {
    let chat: ChatID
    var lastActivity: Date
  }

  private var visits: [Messenger: Visit] = [:]

  public init() {}

  public func isApproved(_ chat: ChatID, at now: Date, idleLimit: TimeInterval?) -> Bool {
    guard let visit = visits[chat.messenger], visit.chat == chat else { return false }
    guard let idleLimit else { return true }
    return now.timeIntervalSince(visit.lastActivity) < idleLimit
  }

  public func recordApproval(of chat: ChatID, at now: Date) {
    visits[chat.messenger] = Visit(chat: chat, lastActivity: now)
  }

  /// A message was sent in an approved chat; restarts the idle timer.
  public func recordActivity(in chat: ChatID, at now: Date) {
    guard visits[chat.messenger]?.chat == chat else { return }
    visits[chat.messenger]?.lastActivity = now
  }

  /// The open conversation changed. Leaving a chat ends its approval, even if you return.
  public func activeChatChanged(in messenger: Messenger, to chat: ChatID?) {
    if visits[messenger]?.chat != chat {
      visits[messenger] = nil
    }
  }
}
