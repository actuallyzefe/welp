import AppKit
import SwiftUI

/// The palette follows the system: settings use native controls, which bring their own colors.
/// What remains here is for Welp's own surfaces (the sidebar, toasts, the badge).
///
/// - `ink`: adaptive neutral for text and surfaces (used at different opacities)
/// - `signal`: the system red, for guarded chats and warnings
/// - `brand`: Welp's red, only for the main calls to action
public enum Theme {
  public static let ink = Color.primary
  public static let signal = Color(nsColor: signalNSColor)
  /// Welp's own red, from the app icon: the color of the main calls to action.
  public static let brand = Color(.sRGB, red: 0.796, green: 0.216, blue: 0.169)

  public static let signalNSColor = NSColor.systemRed

  public static let secondaryText = ink.opacity(0.58)
  public static let raisedSurface = ink.opacity(0.06)
  public static let stroke = ink.opacity(0.08)
  /// The current sidebar item: a neutral gray, never the accent color.
  public static let selection = ink.opacity(0.09)
  public static let hover = ink.opacity(0.04)
  /// The raised knob of a segmented control.
  public static let knob = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x4A4A4E))

  /// Sidebar icon tiles.
  public static let tileTop = Color(nsColor: .adaptive(light: 0xFFFFFF, dark: 0x4A4A4E))
  public static let tileBottom = Color(nsColor: .adaptive(light: 0xEDEDEF, dark: 0x2E2E31))
  public static let tileGlyph = Color(nsColor: .adaptive(light: 0x3A3A3C, dark: 0xF2F2F2))

  public static let cornerRadius: CGFloat = 12

  /// Off when rendering screenshots: views drawn off screen can't show Liquid Glass, so they
  /// use the same look as on macOS before 26.
  @MainActor public static var usesGlass = true
  public static let smallRadius: CGFloat = 9
}

extension NSColor {
  public static func adaptive(light: UInt32, dark: UInt32) -> NSColor {
    NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return NSColor(hex: isDark ? dark : light)
    }
  }

  public convenience init(hex: UInt32) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}

// Liquid Glass needs the macOS 26 SDK (Xcode 26, Swift 6.2) to build. Older Xcodes build
// the fallbacks, so the app can be developed on macOS 14 and 15; releases use Xcode 26.
extension View {
  /// Liquid Glass on macOS 26 and later; a translucent material on older systems.
  @ViewBuilder
  public func glassSurface<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false)
    -> some View
  {
    #if compiler(>=6.2)
      if #available(macOS 26, *), Theme.usesGlass {
        glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
      } else {
        materialSurface(in: shape, tint: tint)
      }
    #else
      materialSurface(in: shape, tint: tint)
    #endif
  }

  private func materialSurface<S: Shape>(in shape: S, tint: Color?) -> some View {
    background(.regularMaterial, in: shape)
      .overlay(shape.fill(tint?.opacity(0.85) ?? .clear))
      .overlay(shape.stroke(Theme.stroke))
  }

  /// The main call to action, in Welp's red unless another tint is given (an app's own color).
  /// One shape and size everywhere: a rounded rectangle, never a capsule. The system's
  /// prominent glass on macOS 26 and later (a glass effect of our own on a button inside a
  /// form breaks how the form draws), a solid fill before.
  @ViewBuilder
  /// `compact` is the regular control size, for small surfaces such as the send prompts.
  public func primaryButtonStyle(tint: Color = Theme.brand, compact: Bool = false) -> some View {
    #if compiler(>=6.2)
      if #available(macOS 26, *), Theme.usesGlass {
        buttonStyle(.glassProminent)
          .buttonBorderShape(.roundedRectangle(radius: PrimaryButtonStyle.cornerRadius))
          .controlSize(compact ? .regular : .large)
          .tint(tint)
      } else {
        buttonStyle(PrimaryButtonStyle(tint: tint, compact: compact))
      }
    #else
      buttonStyle(PrimaryButtonStyle(tint: tint, compact: compact))
    #endif
  }
}

extension NSImage {
  /// Welp's "W!" mark from the bundled SVG, as a template that takes the surrounding color.
  /// Each caller gets its own copy, so sizing one never affects another.
  @MainActor public static var welpMark: NSImage {
    let image = (welpMarkSource.copy() as? NSImage) ?? NSImage()
    image.isTemplate = true
    return image
  }

  @MainActor private static let welpMarkSource: NSImage = {
    let url = Bundle.localization.url(forResource: "MenuBarIcon", withExtension: "svg")
    return url.flatMap(NSImage.init(contentsOf:)) ?? NSImage()
  }()
}

/// Welp's "W!" mark in SwiftUI; size it with `.frame` and color it with `.foregroundStyle`.
public struct WelpMark: View {
  public init() {}

  public var body: some View {
    Image(nsImage: .welpMark)
      .renderingMode(.template)
      .resizable()
      .aspectRatio(contentMode: .fit)
  }
}

extension NSImage {
  /// An app's minimal one-color logo from `Resources/Glyphs` (Simple Icons, CC0), as a
  /// template that takes the surrounding color. Each call returns its own sized copy.
  @MainActor public static func appGlyph(_ name: String, size: CGFloat = 16) -> NSImage {
    let source =
      glyphCache[name]
      ?? {
        let url = Bundle.localization.url(
          forResource: name, withExtension: "svg", subdirectory: "Glyphs")
        let image = url.flatMap(NSImage.init(contentsOf:)) ?? NSImage()
        glyphCache[name] = image
        return image
      }()
    let image = (source.copy() as? NSImage) ?? NSImage()
    image.size = NSSize(width: size, height: size)
    image.isTemplate = true
    return image
  }

  @MainActor private static var glyphCache: [String: NSImage] = [:]
}

/// The call to action before macOS 26: a solid fill in a rounded rectangle, the same shape
/// and size as the system's glass button on later versions.
public struct PrimaryButtonStyle: ButtonStyle {
  public static let cornerRadius: CGFloat = 8
  let tint: Color
  let compact: Bool
  @Environment(\.isEnabled) private var isEnabled

  public init(tint: Color = Theme.brand, compact: Bool = false) {
    self.tint = tint
    self.compact = compact
  }

  public func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    configuration.label
      .font(.system(size: compact ? 12 : 13, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, compact ? 10 : 14)
      .frame(minHeight: compact ? 24 : 30)
      .contentShape(shape)
      .background(tint, in: shape)
      .overlay(shape.strokeBorder(.white.opacity(0.15)))
      .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.snappy(duration: 0.15), value: configuration.isPressed)
  }
}
