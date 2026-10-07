import Foundation

public enum LeaseRequestError: Error, Equatable {
  /// getwelp.io answered that the key doesn't unlock Welp Pro: the subscription has ended,
  /// was refunded, or the key is unknown.
  case denied
  /// No answer worth acting on (offline, timeout, server error): keep the current lease and
  /// try again later.
  case unavailable
}

/// Where leases come from. A port, so the license logic is tested without the network.
public protocol LeaseProvider: Sendable {
  /// A signed lease for `key`, as text; the caller verifies it.
  func lease(for key: String) async throws(LeaseRequestError) -> String
}

/// getwelp.io's lease endpoint. This is the only request Welp Pro makes, and it sends the
/// license key and nothing else: no message contents, chat names, settings or device details.
public struct WelpLeaseProvider: LeaseProvider {
  public static let endpoint = URL(string: "https://www.getwelp.io/api/license/lease")!

  private let endpoint: URL
  private let session: URLSession

  /// An ephemeral session: no cookies or caches are kept between requests.
  public init(endpoint: URL = Self.endpoint, session: URLSession = .init(configuration: .ephemeral))
  {
    self.endpoint = endpoint
    self.session = session
  }

  public func lease(for key: String) async throws(LeaseRequestError) -> String {
    var request = URLRequest(url: endpoint, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONEncoder().encode(LeaseRequest(key: key))

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw .unavailable
    }

    switch (response as? HTTPURLResponse)?.statusCode {
    case 200:
      guard let body = try? JSONDecoder().decode(LeaseResponse.self, from: data) else {
        throw .unavailable
      }
      return body.lease
    case 400, 403:
      throw .denied
    default:
      throw .unavailable
    }
  }

  private struct LeaseRequest: Encodable {
    let key: String
  }

  private struct LeaseResponse: Decodable {
    let lease: String
  }
}
