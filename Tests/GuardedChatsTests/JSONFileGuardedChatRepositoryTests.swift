import Foundation
import GuardedChats
import SharedKernel
import Testing

@Suite struct JSONFileGuardedChatRepositoryTests {
  private let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("welp-tests-\(UUID().uuidString)")
  private var fileURL: URL { directory.appendingPathComponent("nested/guarded-chats.json") }
  private var repository: JSONFileGuardedChatRepository {
    JSONFileGuardedChatRepository(fileURL: fileURL, logger: NullLogger())
  }

  private func write(_ json: String) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(json.utf8).write(to: fileURL)
  }

  @Test func returnsAnEmptyListWhenTheFileIsMissing() throws {
    #expect(try repository.load().isEmpty)
  }

  @Test func roundTripsChatsWithTheirModes() throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let list = GuardedChatList([
      TestChats.guarded(TestChats.whatsApp("2T1K"), .everyMessage),
      TestChats.guarded(TestChats.slack("test", in: "Sentez App Studio"), .undo),
    ])
    try repository.save(list)

    #expect(try repository.load() == list)
    #expect(try String(contentsOf: fileURL, encoding: .utf8).contains("\"version\" : 3"))
  }

  @Test func roundTripsPausedChats() throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let list = GuardedChatList([
      GuardedChat(id: TestChats.whatsApp("2T1K"), mode: .everyMessage, isPaused: true),
      TestChats.guarded(TestChats.whatsApp("Acme"), .undo),
    ])
    try repository.save(list)

    #expect(try repository.load() == list)
    // Active chats are written as before, so older versions still read the file.
    let json = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(json.components(separatedBy: "\"paused\"").count == 2)
  }

  @Test func migratesVersionOneWithTheDefaultMode() throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    try write(#"{ "version": 1, "guardedChats": ["2T1K"] }"#)

    #expect(
      try repository.load()
        == GuardedChatList([TestChats.guarded(TestChats.whatsApp("2T1K"), .default)]))
  }

  @Test func migratesVersionTwoWithTheDefaultMode() throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    try write(
      #"{ "version": 2, "guardedChats": [{ "messenger": "slack", "workspace": "Acme", "name": "genel" }] }"#
    )

    #expect(
      try repository.load()
        == GuardedChatList([TestChats.guarded(TestChats.slack("genel"), .default)]))
  }

  @Test func quarantinesACorruptFile() throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    try write("{ not json")

    #expect(try repository.load().isEmpty)
    let files = try FileManager.default.contentsOfDirectory(
      atPath: fileURL.deletingLastPathComponent().path)
    #expect(files.contains { $0.contains(".corrupt-") })
  }
}
