import GuardedChats
import SharedKernel
import Testing

private struct DiskFullError: Error {}

private final class InMemoryRepository: GuardedChatRepository, @unchecked Sendable {
  var stored: GuardedChatList
  var saveCount = 0
  var failNextSave = false

  init(_ stored: GuardedChatList = .empty) {
    self.stored = stored
  }

  func load() throws -> GuardedChatList { stored }

  func save(_ list: GuardedChatList) throws {
    if failNextSave {
      failNextSave = false
      throw DiskFullError()
    }
    saveCount += 1
    stored = list
  }
}

@MainActor
@Suite struct GuardedChatsServiceTests {
  private let customer = TestChats.whatsApp("Acme Müşteri")

  private func makeService(_ repository: InMemoryRepository = InMemoryRepository()) throws
    -> GuardedChatsService
  {
    let service = GuardedChatsService(repository: repository)
    try service.load()
    return service
  }

  @Test func loadsThePersistedList() throws {
    let service = try makeService(
      InMemoryRepository(GuardedChatList([TestChats.guarded(customer, .undo)])))
    #expect(service.mode(for: customer) == .undo)
    #expect(service.hasAnyGuarded(in: .whatsApp))
    #expect(!service.hasAnyGuarded(in: .slack))
  }

  @Test func protectsAndChangesModes() throws {
    let repository = InMemoryRepository()
    let service = try makeService(repository)

    try service.protect(customer, mode: .firstMessage)
    try service.protect(customer, mode: .everyMessage)
    #expect(repository.stored.mode(for: customer) == .everyMessage)
    #expect(service.chats.count == 1)
  }

  @Test func togglesWithTheGivenMode() throws {
    let service = try makeService()
    #expect(try service.toggle(customer, mode: .undo))
    #expect(service.mode(for: customer) == .undo)
    #expect(try service.toggle(customer, mode: .undo) == false)
    #expect(!service.isGuarded(customer))
  }

  @Test func guardsAnyNumberOfChats() throws {
    let service = try makeService()
    for index in 1...10 { try service.protect(TestChats.slack("kanal-\(index)"), mode: .default) }
    #expect(service.chats.count == 10)
  }

  @Test func unavailableMessengersCannotBeGuardedButKeepTheirChats() throws {
    let slackChat = TestChats.slack("müşteri-acme")
    var slackAvailable = true
    let repository = InMemoryRepository()
    let service = GuardedChatsService(
      repository: repository, isAvailable: { $0 != .slack || slackAvailable })
    try service.load()
    try service.protect(customer, mode: .default)
    try service.protect(slackChat, mode: .everyMessage)

    slackAvailable = false
    #expect(!service.isGuarded(slackChat))
    #expect(service.mode(for: slackChat) == nil)
    #expect(!service.hasAnyGuarded(in: .slack))
    #expect(service.isGuarded(customer))
    #expect(service.chats.count == 2)
    #expect(repository.stored.mode(for: slackChat) == .everyMessage)
    #expect(throws: GuardedChatsError.messengerUnavailable(.slack)) {
      try service.protect(TestChats.slack("genel"), mode: .default)
    }
    #expect(throws: GuardedChatsError.messengerUnavailable(.slack)) {
      try service.toggle(slackChat, mode: .default)
    }

    slackAvailable = true
    #expect(service.mode(for: slackChat) == .everyMessage)
  }

  @Test func chatsOfAnUnavailableMessengerCanStillBeRemoved() throws {
    let slackChat = TestChats.slack("genel")
    let service = GuardedChatsService(
      repository: InMemoryRepository(GuardedChatList([TestChats.guarded(slackChat)])),
      isAvailable: { $0 == .whatsApp })
    try service.load()
    #expect(!service.hasAny)
    try service.unguard(slackChat)
    #expect(service.chats.isEmpty)
  }

  @Test func skipsWritingWhenNothingChanges() throws {
    let repository = InMemoryRepository()
    try makeService(repository).unguard(customer)
    #expect(repository.saveCount == 0)
  }

  @Test func keepsStateUnchangedWhenSavingFails() throws {
    let repository = InMemoryRepository()
    let service = try makeService(repository)
    repository.failNextSave = true

    #expect(throws: DiskFullError.self) { try service.protect(customer, mode: .default) }
    #expect(!service.isGuarded(customer))
  }

  @Test func aPausedChatStaysListedButIsNotGuarded() throws {
    let repository = InMemoryRepository()
    let service = try makeService(repository)
    try service.protect(customer, mode: .everyMessage)

    try service.setPaused(true, for: customer)

    #expect(service.chats.map(\.id) == [customer])
    #expect(service.isPaused(customer))
    #expect(!service.isGuarded(customer))
    #expect(service.mode(for: customer) == nil)
    #expect(!service.hasAnyGuarded(in: .whatsApp))
    #expect(!service.hasAny)
    #expect(service.activeChats.isEmpty)
    #expect(repository.stored.isPaused(customer))
  }

  @Test func changingTheModeKeepsAChatPaused() throws {
    let service = try makeService()
    try service.protect(customer, mode: .firstMessage)
    try service.setPaused(true, for: customer)

    try service.setMode(.undo, for: customer)

    #expect(service.isPaused(customer))
    #expect(service.chats.first?.mode == .undo)
  }

  @Test func protectingAPausedChatResumesIt() throws {
    let service = try makeService()
    try service.protect(customer, mode: .firstMessage)
    try service.setPaused(true, for: customer)

    try service.protect(customer, mode: .firstMessage)

    #expect(!service.isPaused(customer))
    #expect(service.mode(for: customer) == .firstMessage)
  }

  @Test func resumingAChatOfAnUnavailableMessengerFails() throws {
    let board = TestChats.slack("board")
    let repository = InMemoryRepository(
      GuardedChatList([GuardedChat(id: board, mode: .undo, isPaused: true)]))
    let service = GuardedChatsService(repository: repository, isAvailable: { $0 == .whatsApp })
    try service.load()

    #expect(throws: GuardedChatsError.messengerUnavailable(.slack)) {
      try service.setPaused(false, for: board)
    }
    #expect(service.isPaused(board))
  }

  @Test func togglingAPausedChatResumesItWithItsOwnMode() throws {
    let service = try makeService()
    try service.protect(customer, mode: .undo)
    try service.setPaused(true, for: customer)

    #expect(try service.toggle(customer, mode: .everyMessage))

    #expect(service.mode(for: customer) == .undo)
  }
}
