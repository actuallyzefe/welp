import CryptoKit
import Foundation
import Testing

@testable import Licensing

/// Issues keys and leases the way the store backend does, with a throwaway signing key.
struct TestIssuer {
  let privateKey = Curve25519.Signing.PrivateKey()

  var verifier: LicenseVerifier {
    LicenseVerifier(publicKey: privateKey.publicKey.rawRepresentation)
  }

  func key(
    v: Int = 2, product: String = "welp-pro", email: String = "ada@example.com",
    subscription: String = "sub_123"
  ) throws -> String {
    try signed(
      #"{"v":\#(v),"product":"\#(product)","type":"key","email":"\#(email)","subscription":"\#(subscription)"}"#
    )
  }

  func lease(
    subscription: String = "sub_123", issued: Date = TestIssuer.day(0),
    expires: Date = TestIssuer.day(30)
  ) throws -> String {
    let format = ISO8601DateFormatter()
    return try signed(
      #"{"v":2,"product":"welp-pro","type":"lease","subscription":"\#(subscription)","issued":"\#(format.string(from: issued))","expires":"\#(format.string(from: expires))"}"#
    )
  }

  func signed(_ json: String) throws -> String {
    let payload = Data(json.utf8)
    let signature = try privateKey.signature(for: payload)
    return LicenseVerifier.prefix + payload.base64URL + "." + signature.base64URL
  }

  /// Midnight UTC, `n` days after 5 October 2026.
  static func day(_ n: Double) -> Date {
    Date(timeIntervalSince1970: 1_791_158_400 + n * 86_400)
  }
}

extension Data {
  var base64URL: String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

@Suite struct LicenseVerifierTests {
  private let issuer = TestIssuer()

  @Test func acceptsAKeySignedByWelp() throws {
    let license = try issuer.verifier.verifyKey(try issuer.key())
    #expect(license == License(email: "ada@example.com", subscriptionID: "sub_123"))
  }

  @Test func acceptsALeaseSignedByWelp() throws {
    let lease = try issuer.verifier.verifyLease(try issuer.lease())
    #expect(
      lease
        == Lease(
          subscriptionID: "sub_123", issuedAt: TestIssuer.day(0), expiresAt: TestIssuer.day(30)))
  }

  @Test func ignoresWhitespaceFromMailClients() throws {
    let key = try issuer.key()
    let wrapped = "  " + key.prefix(20) + "\n" + key.dropFirst(20) + " \n"
    #expect(try issuer.verifier.verifyKey(String(wrapped)).email == "ada@example.com")
  }

  @Test func rejectsAKeySignedBySomeoneElse() throws {
    let forged = try TestIssuer().key()
    #expect(throws: LicenseError.invalidSignature) { try issuer.verifier.verifyKey(forged) }
  }

  @Test func rejectsALeaseSignedBySomeoneElse() throws {
    let forged = try TestIssuer().lease(expires: TestIssuer.day(10_000))
    #expect(throws: LicenseError.invalidSignature) { try issuer.verifier.verifyLease(forged) }
  }

  @Test func rejectsAChangedPayload() throws {
    let key = try issuer.key()
    let parts = key.dropFirst(LicenseVerifier.prefix.count).split(separator: ".")
    let otherPayload = Data(
      #"{"v":2,"product":"welp-pro","type":"key","email":"eve@example.com","subscription":"sub_123"}"#
        .utf8)
    let tampered = LicenseVerifier.prefix + otherPayload.base64URL + "." + parts[1]
    #expect(throws: LicenseError.invalidSignature) { try issuer.verifier.verifyKey(tampered) }
  }

  @Test(arguments: ["", "hello", "WELP-", "WELP-abc", "WELP-a.b.c", "WELP-!!!.???"])
  func rejectsMalformedKeys(_ key: String) {
    #expect(throws: LicenseError.malformed) { try issuer.verifier.verifyKey(key) }
  }

  @Test func rejectsOtherProductsAndVersions() throws {
    #expect(throws: LicenseError.unsupported) {
      try issuer.verifier.verifyKey(try issuer.key(product: "welp-teams"))
    }
    #expect(throws: LicenseError.unsupported) {
      try issuer.verifier.verifyKey(try issuer.key(v: 3))
    }
  }

  @Test func rejectsOneTimePurchaseKeys() throws {
    let legacy = try issuer.signed(
      #"{"v":1,"product":"welp-pro","email":"ada@example.com","purchase":"txn_123","issued":"2026-10-05T12:00:00Z"}"#
    )
    #expect(throws: LicenseError.unsupported) { try issuer.verifier.verifyKey(legacy) }
  }

  @Test func aLeaseIsNotAKeyAndAKeyIsNotALease() throws {
    #expect(throws: LicenseError.unsupported) { try issuer.verifier.verifyKey(try issuer.lease()) }
    #expect(throws: LicenseError.unsupported) { try issuer.verifier.verifyLease(try issuer.key()) }
  }

  @Test func shipsAValidPublicKey() {
    // A broken embedded key would reject every purchase.
    #expect(throws: LicenseError.invalidSignature) {
      try LicenseVerifier.welp.verifyKey(try issuer.key())
    }
  }
}
