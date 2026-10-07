import Foundation
import Testing

/// Guards the String Catalog, so a missing or broken translation fails CI instead of
/// silently showing English (or crashing on a bad format specifier) at runtime.
///
/// Adding a language means adding it to `CFBundleLocalizations` in `Support/Info.plist`
/// and translating every string in the catalog; these tests then cover it automatically.
@Suite struct StringCatalogTests {
  private static let root = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

  /// The core's catalog, then Welp Pro's (ee/) when it is part of the checkout.
  private static let catalogPaths = [
    "Sources/WelpApp/Resources/Localizable.xcstrings",
    "ee/Sources/WelpProEdition/Resources/Localizable.xcstrings",
  ]

  private let catalogs: [Catalog]
  private let appLanguages: Set<String>

  init() throws {
    catalogs = try Self.catalogPaths
      .map { Self.root.appending(path: $0) }
      .filter { FileManager.default.fileExists(atPath: $0.path()) }
      .map { try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: $0)) }

    let plistURL = Self.root.appending(path: "Support/Info.plist")
    let plist = try PropertyListSerialization.propertyList(
      from: Data(contentsOf: plistURL), format: nil)
    let languages = (plist as? [String: Any])?["CFBundleLocalizations"] as? [String] ?? []
    appLanguages = Set(languages)
  }

  private var translations: Set<String> { appLanguages.subtracting(["en"]) }

  /// Every string of every catalog.
  private var strings: [(key: String, entry: Entry)] {
    catalogs.flatMap { $0.strings.map { (key: $0.key, entry: $0.value) } }
  }

  @Test func appDeclaresTheSourceLanguageAndAtLeastOneTranslation() {
    #expect(!catalogs.isEmpty)
    for catalog in catalogs { #expect(appLanguages.contains(catalog.sourceLanguage)) }
    #expect(!translations.isEmpty)
  }

  @Test func catalogHasNoLanguagesTheAppDoesNotDeclare() {
    let used = Set(strings.flatMap { ($0.entry.localizations ?? [:]).keys })
    #expect(used.isSubset(of: appLanguages), "Add them to CFBundleLocalizations in Info.plist")
  }

  @Test func everyStringIsTranslatedIntoEveryLanguage() {
    for (key, entry) in strings {
      for language in translations {
        let values = entry.localizations?[language]?.allUnits ?? []
        #expect(!values.isEmpty, "“\(key)” has no \(language) translation")
        for unit in values {
          #expect(unit.state == "translated", "“\(key)” (\(language)) is \(unit.state)")
          #expect(!unit.value.isEmpty, "“\(key)” (\(language)) is empty")
        }
      }
    }
  }

  @Test func translationsKeepTheFormatSpecifiers() {
    for (key, entry) in strings {
      let expected = Self.specifiers(in: key)
      for (language, localization) in entry.localizations ?? [:] {
        for unit in localization.allUnits {
          #expect(
            Self.specifiers(in: unit.value) == expected,
            "“\(key)” (\(language)): “\(unit.value)” changes the format specifiers")
        }
      }
    }
  }

  @Test func everyStringExplainsItsContextToTranslators() {
    for (key, entry) in strings {
      #expect(entry.comment?.isEmpty == false, "“\(key)” needs a comment")
    }
  }

  @Test func catalogHasNoStaleStrings() {
    for (key, entry) in strings {
      #expect(entry.extractionState != "stale", "“\(key)” is unused; run `make strings`")
    }
  }

  /// `%@`, `%lld`, `%1$@`… sorted by position, positions removed: translations may reorder
  /// arguments with positional specifiers, but must keep their number and types.
  private static func specifiers(in text: String) -> [String] {
    let pattern = /%(?:(\d+)\$)?(@|lld|ld|d|f|\.\d+f)/
    let matches = text.matches(of: pattern).enumerated().map { index, match in
      (position: match.output.1.flatMap { Int($0) } ?? index + 1, type: String(match.output.2))
    }
    return matches.sorted { $0.position < $1.position }.map(\.type)
  }
}

// MARK: Catalog format (the parts these tests need)

private struct Catalog: Decodable {
  let sourceLanguage: String
  let strings: [String: Entry]
}

private struct Entry: Decodable {
  let comment: String?
  let extractionState: String?
  let localizations: [String: Localization]?
}

private struct Localization: Decodable {
  let stringUnit: StringUnit?
  let variations: [String: [String: Localization]]?

  /// The plain value, or every variation (e.g. plural forms), however deeply nested.
  var allUnits: [StringUnit] {
    (stringUnit.map { [$0] } ?? [])
      + (variations?.values.flatMap { $0.values.flatMap(\.allUnits) } ?? [])
  }
}

private struct StringUnit: Decodable {
  let state: String
  let value: String
}
