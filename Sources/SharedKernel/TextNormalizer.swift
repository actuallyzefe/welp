import Foundation

/// Cleans text read from other apps' UI, which is often sprinkled with bidi marks.
public enum TextNormalizer {
  /// NFC-normalizes, strips invisible formatting characters (Unicode category Cf)
  /// and collapses whitespace runs into single spaces.
  public static func normalize(_ text: String) -> String {
    let visible = text.precomposedStringWithCanonicalMapping.unicodeScalars
      .filter { $0.properties.generalCategory != .format }
    return String(String.UnicodeScalarView(visible))
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }
}
