import GuardedChats
import SharedKernel

enum TestChats {
  static func whatsApp(_ name: String) -> ChatID {
    ChatID(messenger: .whatsApp, name: ChatName(name)!)
  }

  static func slack(_ name: String, in workspace: String = "Acme") -> ChatID {
    ChatID(messenger: .slack, workspace: ChatName(workspace), name: ChatName(name)!)
  }

  static func guarded(_ id: ChatID, _ mode: ProtectionMode = .default) -> GuardedChat {
    GuardedChat(id: id, mode: mode)
  }
}
