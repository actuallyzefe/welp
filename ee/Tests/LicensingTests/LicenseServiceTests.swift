import Foundation
import Testing

@testable import Licensing

private final class InMemoryStore: LicenseStore, @unchecked Sendable {
  var license: StoredLicense?

  init(_ license: StoredLicense? = nil) {
    self.license = license
  }

  func load() -> StoredLicense? { license }
  func save(_ license: StoredLicense?) { self.license = license }
}

/// getwelp.io, answering with whatever the test sets.
private final class FakeProvider: LeaseProvider, @unchecked Sendable {
  var answer: Result<String, LeaseRequestError> = .failure(.unavailable)
  var requests: [String] = []

  func lease(for key: String) async throws(LeaseRequestError) -> String {
    requests.append(key)
    return try answer.get()
  }
}

/// A clock the test moves by hand.
private final class TestClock: @unchecked Sendable {
  var now = TestIssuer.day(0)
  var read: @Sendable () -> Date { { self.now } }
}

// The fakes are only touched from the main actor (the service and the tests); they are
// @unchecked Sendable to cross into the service's nonisolated ports.
@MainActor
@Suite struct LicenseServiceTests {
  private let issuer = TestIssuer()
  private let store = InMemoryStore()
  private let provider = FakeProvider()
  private let clock = TestClock()

  private func service() -> LicenseService {
    LicenseService(verifier: issuer.verifier, store: store, provider: provider, clock: clock.read)
  }

  private var license: License { License(email: "ada@example.com", subscriptionID: "sub_123") }

  @Test func startsOnTheFreePlan() {
    #expect(service().status == .free)
  }

  @Test func activatingAPaidKeyUnlocksProAndKeepsTheKey() async throws {
    provider.answer = .success(try issuer.lease())
    let service = service()
    let key = try issuer.key()

    try await service.activate(" \(key)\n")

    #expect(service.status == .active(license, until: TestIssuer.day(30)))
    #expect(provider.requests == [key])
    #expect(store.license?.key == key)
    #expect(self.service().isPro)
  }

  @Test func aKeyAloneIsNotEnough() async throws {
    let service = service()
    try await service.activate(try issuer.key())
    #expect(service.status == .unconfirmed(license))
    #expect(service.isUnreachable)
    #expect(!service.isPro)
  }

  @Test func anEndedSubscriptionDoesNotUnlockPro() async throws {
    provider.answer = .failure(.denied)
    let service = service()
    try await service.activate(try issuer.key())
    #expect(service.status == .ended(license))
    #expect(self.service().status == .ended(license))
  }

  @Test func proStopsWhenTheLeaseRunsOut() async throws {
    provider.answer = .success(try issuer.lease(expires: TestIssuer.day(30)))
    let service = service()
    try await service.activate(try issuer.key())

    clock.now = TestIssuer.day(29.9)
    service.refreshStatus()
    #expect(service.isPro)

    clock.now = TestIssuer.day(30)
    service.refreshStatus()
    #expect(service.status == .unconfirmed(license))
  }

  @Test func settingTheClockBackDoesNotReviveALease() async throws {
    provider.answer = .success(try issuer.lease(expires: TestIssuer.day(30)))
    let service = service()
    try await service.activate(try issuer.key())

    clock.now = TestIssuer.day(40)
    service.refreshStatus()
    clock.now = TestIssuer.day(10)
    service.refreshStatus()
    #expect(!service.isPro)
    #expect(!self.service().isPro)
  }

  @Test func aRenewedLeaseUndoesAClockThatRanAhead() async throws {
    provider.answer = .success(try issuer.lease())
    let service = service()
    try await service.activate(try issuer.key())
    clock.now = TestIssuer.day(400)
    service.refreshStatus()
    #expect(!service.isPro)

    clock.now = TestIssuer.day(1)
    provider.answer = .success(
      try issuer.lease(issued: TestIssuer.day(1), expires: TestIssuer.day(31)))
    await service.renew()
    #expect(service.status == .active(license, until: TestIssuer.day(31)))
  }

  @Test func stayingOfflineKeepsTheCurrentLease() async throws {
    provider.answer = .success(try issuer.lease())
    let service = service()
    try await service.activate(try issuer.key())

    provider.answer = .failure(.unavailable)
    clock.now = TestIssuer.day(8)
    await service.renew()
    #expect(service.status == .active(license, until: TestIssuer.day(30)))
    #expect(service.isUnreachable)
  }

  @Test func aCanceledSubscriptionStopsProAtTheNextRenewal() async throws {
    provider.answer = .success(try issuer.lease())
    let service = service()
    try await service.activate(try issuer.key())

    provider.answer = .failure(.denied)
    await service.renew()
    #expect(service.status == .ended(license))
  }

  @Test func rejectsALeaseForAnotherSubscription() async throws {
    provider.answer = .success(try issuer.lease(subscription: "sub_other"))
    let service = service()
    try await service.activate(try issuer.key())
    #expect(service.status == .unconfirmed(license))
  }

  @Test func renewsWeeklyAndEarlyBeforeTheLeaseRunsOut() async throws {
    provider.answer = .success(try issuer.lease(expires: TestIssuer.day(30)))
    let service = service()
    #expect(!service.isRenewalDue)
    try await service.activate(try issuer.key())
    #expect(!service.isRenewalDue)

    clock.now = TestIssuer.day(7)
    #expect(service.isRenewalDue)

    provider.answer = .success(
      try issuer.lease(issued: TestIssuer.day(7), expires: TestIssuer.day(11)))
    await service.renew()
    #expect(!service.isRenewalDue)
    clock.now = TestIssuer.day(8)
    #expect(service.isRenewalDue)
  }

  @Test func anInvalidKeyKeepsTheCurrentLicense() async throws {
    provider.answer = .success(try issuer.lease())
    let service = service()
    let key = try issuer.key()
    try await service.activate(key)

    await #expect(throws: LicenseError.invalidSignature) {
      try await service.activate(try TestIssuer().key())
    }
    #expect(service.isPro)
    #expect(store.license?.key == key)
  }

  @Test func aStoredKeyIsVerifiedAgainOnLaunch() throws {
    store.license = StoredLicense(key: try TestIssuer().key(), lease: try TestIssuer().lease())
    #expect(service().status == .free)
  }

  @Test func removingGoesBackToTheFreePlan() async throws {
    provider.answer = .success(try issuer.lease())
    let service = service()
    try await service.activate(try issuer.key())
    service.remove()
    #expect(service.status == .free)
    #expect(store.license == nil)
  }
}
