import Foundation
import Observation

/// What is kept between launches. The key and lease are verified again on every launch
/// rather than trusted from storage.
public struct StoredLicense: Codable, Equatable, Sendable {
  public var key: String
  public var lease: String?
  /// The latest time this Mac has seen, from its own clock or getwelp.io's, so setting the
  /// clock back doesn't bring an expired lease back to life.
  public var latestTime: Date?
  /// getwelp.io said the subscription no longer pays for Welp Pro.
  public var hasEnded: Bool

  public init(key: String, lease: String? = nil, latestTime: Date? = nil, hasEnded: Bool = false) {
    self.key = key
    self.lease = lease
    self.latestTime = latestTime
    self.hasEnded = hasEnded
  }
}

/// Where the license is kept between launches.
public protocol LicenseStore: Sendable {
  func load() -> StoredLicense?
  func save(_ license: StoredLicense?)
}

public enum LicenseStatus: Equatable, Sendable {
  /// No license key: the open-source core's features only.
  case free
  /// The subscription is paid up; Welp Pro works until the lease runs out.
  case active(License, until: Date)
  /// A key is entered, but getwelp.io hasn't confirmed the subscription yet, or the last
  /// confirmation ran out while the Mac was offline.
  case unconfirmed(License)
  /// getwelp.io said the subscription has ended (canceled, unpaid or refunded).
  case ended(License)
}

/// The Welp Pro license of this Mac, if any. Observable, so UIs update on activation.
///
/// The license key is permanent; Welp Pro only works while a lease from getwelp.io is
/// current. The app renews the lease about once a week, and each lease lasts long enough
/// (getwelp.io decides, about a month) to work offline in between. Once the subscription
/// ends, getwelp.io stops issuing leases and Welp Pro stops when the last one runs out.
@MainActor
@Observable
public final class LicenseService {
  public private(set) var status: LicenseStatus = .free
  public private(set) var isRenewing = false
  /// The last renewal couldn't reach getwelp.io.
  public private(set) var isUnreachable = false

  /// How often the lease is renewed while things are fine.
  static let renewalInterval: TimeInterval = 7 * 86_400
  /// Renews early when the lease is about to run out, e.g. a short one while a payment is retried.
  static let renewalMargin: TimeInterval = 3 * 86_400
  /// How often an ended subscription is checked again, in case it was resumed.
  static let endedRecheckInterval: TimeInterval = 86_400
  /// How often `keepRenewing` looks at whether a renewal is due.
  static let checkInterval: Duration = .seconds(3_600)

  @ObservationIgnored private let verifier: LicenseVerifier
  @ObservationIgnored private let store: any LicenseStore
  @ObservationIgnored private let provider: any LeaseProvider
  @ObservationIgnored private let clock: @Sendable () -> Date
  @ObservationIgnored private var stored: StoredLicense?
  @ObservationIgnored private var lastAttempt: Date?

  public init(
    verifier: LicenseVerifier = .welp,
    store: any LicenseStore,
    provider: any LeaseProvider = WelpLeaseProvider(),
    clock: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.verifier = verifier
    self.store = store
    self.provider = provider
    self.clock = clock
    stored = store.load()
    refreshStatus()
  }

  public var isPro: Bool {
    if case .active = status { true } else { false }
  }

  /// The entered license, whatever the state of its subscription.
  public var license: License? {
    switch status {
    case .free: nil
    case .active(let license, _), .unconfirmed(let license), .ended(let license): license
    }
  }

  /// Verifies `key`, keeps it and confirms its subscription with getwelp.io. Leaves the
  /// current license untouched if the key is invalid.
  public func activate(_ key: String) async throws(LicenseError) {
    _ = try verifier.verifyKey(key)
    let compact = String(key.filter { !$0.isWhitespace })
    // Entering the same key again keeps its lease.
    let lease = compact == stored?.key ? stored?.lease : nil
    save(StoredLicense(key: compact, lease: lease, latestTime: stored?.latestTime))
    refreshStatus()
    await renew()
  }

  /// Back to the free plan.
  public func remove() {
    save(nil)
    isUnreachable = false
    refreshStatus()
  }

  /// Asks getwelp.io for a new lease. Keeps the current one if getwelp.io can't be reached.
  public func renew() async {
    guard let current = stored, !isRenewing else { return }
    isRenewing = true
    defer { isRenewing = false }
    lastAttempt = clock()

    do throws(LeaseRequestError) {
      let text = try await provider.lease(for: current.key)
      // The key may have been replaced or removed while the request was out.
      guard stored?.key == current.key else { return }
      guard let lease = try? verifier.verifyLease(text),
        let license = try? verifier.verifyKey(current.key),
        lease.subscriptionID == license.subscriptionID
      else {
        isUnreachable = true
        refreshStatus()
        return
      }
      // getwelp.io's clock replaces ours as the latest time: a Mac clock that ran ahead
      // can't lock Welp Pro, and one set back can't revive an old lease.
      save(StoredLicense(key: current.key, lease: text, latestTime: lease.issuedAt))
      isUnreachable = false
    } catch {
      guard stored?.key == current.key else { return }
      switch error {
      case .denied:
        save(StoredLicense(key: current.key, latestTime: current.latestTime, hasEnded: true))
        isUnreachable = false
      case .unavailable:
        isUnreachable = true
      }
    }
    refreshStatus()
  }

  /// Whether a renewal should be attempted now.
  public var isRenewalDue: Bool {
    guard let current = stored else { return false }
    if current.hasEnded {
      return lastAttempt.map { clock().timeIntervalSince($0) >= Self.endedRecheckInterval } ?? true
    }
    guard let text = current.lease, let lease = try? verifier.verifyLease(text) else { return true }
    let now = latestTime(current)
    return now.timeIntervalSince(lease.issuedAt) >= Self.renewalInterval
      || lease.expiresAt.timeIntervalSince(now) <= Self.renewalMargin
  }

  /// Keeps the lease fresh for as long as the app runs. Returns when the task is cancelled.
  public func keepRenewing() async {
    while !Task.isCancelled {
      if isRenewalDue {
        await renew()
      } else {
        refreshStatus()
      }
      try? await Task.sleep(for: Self.checkInterval)
    }
  }

  /// Works the status out again from what is stored and the time: a lease runs out without
  /// anything else changing.
  public func refreshStatus() {
    guard var current = stored, let license = try? verifier.verifyKey(current.key) else {
      status = .free
      return
    }
    let now = latestTime(current)
    if current.latestTime != now {
      current.latestTime = now
      save(current)
    }

    if current.hasEnded {
      status = .ended(license)
    } else if let text = current.lease, let lease = try? verifier.verifyLease(text),
      lease.subscriptionID == license.subscriptionID, now < lease.expiresAt
    {
      status = .active(license, until: lease.expiresAt)
    } else {
      status = .unconfirmed(license)
    }
  }

  /// The Mac's clock, unless it is behind a time already seen.
  private func latestTime(_ license: StoredLicense) -> Date {
    max(clock(), license.latestTime ?? .distantPast)
  }

  private func save(_ license: StoredLicense?) {
    stored = license
    store.save(license)
  }
}
