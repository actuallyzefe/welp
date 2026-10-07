import Foundation
import SharedKernel

/// Stores the guarded chat list as versioned JSON, written atomically.
///
/// - v1: `["Chat name", …]` (WhatsApp only)
/// - v2: `[{ "messenger", "workspace"?, "name" }, …]`
/// - v3: v2 plus `"mode"`, and optionally `"paused": true` (absent means active)
///
/// Older versions are migrated on load with the default protection mode.
public final class JSONFileGuardedChatRepository: GuardedChatRepository {
  private struct Header: Decodable {
    var version: Int
  }

  private struct FileV1: Decodable {
    var guardedChats: [String]
  }

  private struct Entry: Codable {
    var messenger: Messenger
    var workspace: String?
    var name: String
    var mode: ProtectionMode?
    var paused: Bool?
  }

  private struct FileV3: Codable {
    static let version = 3
    var version = FileV3.version
    var guardedChats: [Entry]
  }

  private let fileURL: URL
  private let logger: any AppLogger

  public init(fileURL: URL, logger: any AppLogger) {
    self.fileURL = fileURL
    self.logger = logger
  }

  public func load() throws -> GuardedChatList {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch CocoaError.fileReadNoSuchFile {
      return .empty
    }

    guard let chats = decode(data) else {
      try quarantineCorruptFile()
      return .empty
    }
    return GuardedChatList(chats)
  }

  public func save(_ list: GuardedChatList) throws {
    let contents = FileV3(
      guardedChats: list.sorted.map {
        Entry(
          messenger: $0.id.messenger, workspace: $0.id.workspace?.value, name: $0.id.name.value,
          mode: $0.mode, paused: $0.isPaused ? true : nil)
      }
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try encoder.encode(contents).write(to: fileURL, options: .atomic)
  }

  private func decode(_ data: Data) -> [GuardedChat]? {
    let decoder = JSONDecoder()
    switch (try? decoder.decode(Header.self, from: data))?.version {
    case 1:
      return (try? decoder.decode(FileV1.self, from: data))?.guardedChats.compactMap { raw in
        ChatName(raw).map {
          GuardedChat(id: ChatID(messenger: .whatsApp, name: $0), mode: .default)
        }
      }
    case 2, FileV3.version:
      return (try? decoder.decode(FileV3.self, from: data))?.guardedChats.compactMap { entry in
        ChatName(entry.name).map {
          GuardedChat(
            id: ChatID(messenger: entry.messenger, workspace: ChatName(entry.workspace), name: $0),
            mode: entry.mode ?? .default, isPaused: entry.paused ?? false)
        }
      }
    default:
      return nil
    }
  }

  private func quarantineCorruptFile() throws {
    let backupURL = fileURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
    logger.error("Guarded chats file is unreadable; moved to \(backupURL.lastPathComponent)")
    try FileManager.default.moveItem(at: fileURL, to: backupURL)
  }
}
