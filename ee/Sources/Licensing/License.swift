import CryptoKit
import Foundation

/// A Welp Pro license key: who subscribed, and to which subscription. It proves the purchase,
/// not that the subscription is still paid; a `Lease` does that.
public struct License: Equatable, Sendable {
  public let email: String
  /// The store's subscription ID: the license's identity, the same for its whole life.
  public let subscriptionID: String

  public init(email: String, subscriptionID: String) {
    self.email = email
    self.subscriptionID = subscriptionID
  }
}

/// Proof from getwelp.io that a subscription is paid up: Welp Pro works until `expiresAt`.
/// The app fetches a new one with the license key about once a week.
public struct Lease: Equatable, Sendable {
  public let subscriptionID: String
  /// getwelp.io's clock when it issued the lease, so a Mac's clock set back is noticed.
  public let issuedAt: Date
  public let expiresAt: Date

  public init(subscriptionID: String, issuedAt: Date, expiresAt: Date) {
    self.subscriptionID = subscriptionID
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
  }
}

public enum LicenseError: Error, Equatable {
  /// Not a Welp license key at all (typo, truncated paste).
  case malformed
  /// Well-formed, but not signed by Welp, or changed after signing.
  case invalidSignature
  /// Signed by Welp, but for another product or another key format (such as a lease, or a
  /// key from before Welp Pro was a subscription).
  case unsupported
}

/// Checks license keys and leases offline: both are payloads signed with Welp's private
/// Ed25519 key, and only the public half ships in the app.
///
/// Format: `WELP-<payload>.<signature>`, both base64url without padding; the payload is JSON,
/// `{"v":2,"product":"welp-pro","type":"key","email":…,"subscription":…}` for a key and
/// `{"v":2,"product":"welp-pro","type":"lease","subscription":…,"issued":…,"expires":…}`
/// (ISO 8601) for a lease.
public struct LicenseVerifier: Sendable {
  public static let prefix = "WELP-"
  static let product = "welp-pro"
  static let version = 2

  /// Welp's public signing key. The private half stays with the store backend.
  public static let welp = LicenseVerifier(
    publicKey: Data(base64Encoded: "j4MwBpq1pjDRPXLWDEI9L1GxZlKOsM7nQWdJ7ADLK9g=")!)

  private let publicKey: Data

  public init(publicKey: Data) {
    self.publicKey = publicKey
  }

  public func verifyKey(_ key: String) throws(LicenseError) -> License {
    let fields: KeyPayload = try verified(key, type: "key")
    return License(email: fields.email, subscriptionID: fields.subscription)
  }

  public func verifyLease(_ lease: String) throws(LicenseError) -> Lease {
    let fields: LeasePayload = try verified(lease, type: "lease")
    return Lease(
      subscriptionID: fields.subscription, issuedAt: fields.issued, expiresAt: fields.expires)
  }

  private func verified<Payload: Decodable>(_ text: String, type: String) throws(LicenseError)
    -> Payload
  {
    // Mail clients wrap long lines; whitespace is never part of a key.
    let compact = String(text.filter { !$0.isWhitespace })
    guard compact.hasPrefix(Self.prefix) else { throw .malformed }
    let parts = compact.dropFirst(Self.prefix.count).split(
      separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 2,
      let payload = Data(base64URLEncoded: parts[0]),
      let signature = Data(base64URLEncoded: parts[1])
    else { throw .malformed }

    guard let signingKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey),
      signingKey.isValidSignature(signature, for: payload)
    else { throw .invalidSignature }

    let decoder = JSONDecoder.license
    guard let envelope = try? decoder.decode(Envelope.self, from: payload),
      envelope.v == Self.version, envelope.product == Self.product, envelope.type == type,
      let fields = try? decoder.decode(Payload.self, from: payload)
    else { throw .unsupported }
    return fields
  }

  struct Envelope: Decodable {
    let v: Int
    let product: String
    let type: String?
  }

  struct KeyPayload: Decodable {
    let email: String
    let subscription: String
  }

  struct LeasePayload: Decodable {
    let subscription: String
    let issued: Date
    let expires: Date
  }
}

extension JSONDecoder {
  fileprivate static var license: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

extension Data {
  init?(base64URLEncoded text: some StringProtocol) {
    var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(
      of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    self.init(base64Encoded: base64)
  }
}
