import SharedKernel
import SwiftUI

/// The label of a settings row: an icon (an SF Symbol, or Welp's own mark where the row is
/// about Welp itself), a title and an optional explanation, with room to breathe. Used for every
/// row so icons line up and rows share one height.
public struct SettingLabel: View {
  let title: String
  var detail: String?
  var symbol: String?
  /// An app's logo (see `NSImage.appGlyph`), used when there is no SF Symbol.
  var glyph: String?
  var symbolStyle: AnyShapeStyle = AnyShapeStyle(.secondary)

  public init(
    title: String, detail: String? = nil, symbol: String?, glyph: String? = nil,
    symbolStyle: AnyShapeStyle = AnyShapeStyle(.secondary)
  ) {
    self.title = title
    self.detail = detail
    self.symbol = symbol
    self.glyph = glyph
    self.symbolStyle = symbolStyle
  }

  /// A row with Welp's "W!" mark as its icon.
  public static func welp(title: String, detail: String?) -> SettingLabel {
    SettingLabel(title: title, detail: detail, symbol: nil)
  }

  public var body: some View {
    // Laid out by hand rather than with `Label`, which pins the icon to the first line:
    // here it sits centered on the title and the explanation together.
    HStack(alignment: .center, spacing: 10) {
      Group {
        if let symbol {
          Image(systemName: symbol)
        } else if let glyph {
          Image(nsImage: .appGlyph(glyph)).renderingMode(.template)
        } else {
          WelpMark().frame(height: 14)
        }
      }
      .foregroundStyle(symbolStyle)
      .frame(width: 20)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        if let detail {
          Text(detail)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .combine)
  }
}

/// The badge shown above a guarded chat's message box (also used as a live preview).
struct GuardBadge: View {
  let chatName: String
  let mode: ProtectionMode

  var body: some View {
    // Neutral glass (a material before macOS 26) with adaptive text, readable over light and
    // dark chats alike; the red W! mark carries the warning.
    HStack(spacing: 6) {
      WelpMark()
        .frame(height: 12)
        .foregroundStyle(Theme.signal)
      Text(verbatim: chatName)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)
      // The mode as a status, icon and name, so it doesn't read as a button.
      HStack(spacing: 3) {
        Image(systemName: mode.symbol)
          .font(.system(size: 9, weight: .semibold))
        Text(mode.shortTitle)
          .font(.system(size: 11, weight: .medium))
      }
      .foregroundStyle(.secondary)
      .padding(.leading, 2)
    }
    // Always at its full width: its window is sized to fit it, rounded to whole points, and
    // the fraction lost to rounding would otherwise truncate the mode ("First mess…").
    .fixedSize()
    .padding(.horizontal, 10)
    .frame(height: 24)
    .glassSurface(in: Capsule())
  }
}
