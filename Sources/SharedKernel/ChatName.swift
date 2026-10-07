import Foundation

/// A WhatsApp chat, identified by its display name.
///
/// Names are normalized (Unicode NFC, invisible formatting characters removed, whitespace
/// collapsed) and compared case-insensitively using Turkish casing rules.
public struct ChatName: Hashable, Sendable, CustomStringConvertible {
  public static let maxLength = 256
  private static let turkish = Locale(identifier: "tr_TR")

  /// Normalized, human-readable name.
  public let value: String
  /// Comparison key.
  public let key: String

  public init?(_ raw: String?) {
    guard let raw else { return nil }
    let normalized = TextNormalizer.normalize(raw)
    guard !normalized.isEmpty, normalized.count <= Self.maxLength else { return nil }
    value = normalized
    key = normalized.lowercased(with: Self.turkish)
  }

  public static func == (lhs: ChatName, rhs: ChatName) -> Bool {
    lhs.key == rhs.key
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(key)
  }

  public var description: String { value }
}
