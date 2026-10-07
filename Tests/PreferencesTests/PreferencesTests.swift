import Foundation
import Preferences
import SharedKernel
import Testing

@Suite struct PreferencesTests {
  @Test func decodesOlderBlobsWithDefaultsForMissingKeys() throws {
    let data = Data(#"{ "defaultMode": "undo" }"#.utf8)
    let decoded = try JSONDecoder().decode(Preferences.self, from: data)

    #expect(decoded.defaultMode == .undo)
    #expect(decoded.idleMinutes == Preferences.standard.idleMinutes)
    #expect(decoded.showsComposerBadge)
  }

  @MainActor
  @Test func persistsUpdatesThroughTheStore() throws {
    let defaults = UserDefaults(suiteName: "welp-tests-\(UUID().uuidString)")!
    let store = UserDefaultsPreferencesStore(defaults: defaults, logger: NullLogger())
    let service = PreferencesService(store: store)

    try service.update { $0.undoSeconds = 10 }

    #expect(service.current.undoSeconds == 10)
    #expect(store.load().undoSeconds == 10)
  }

  @Test func fallsBackToDefaultsWhenTheBlobIsCorrupt() {
    let defaults = UserDefaults(suiteName: "welp-tests-\(UUID().uuidString)")!
    defaults.set(Data("nope".utf8), forKey: "preferences")
    let store = UserDefaultsPreferencesStore(defaults: defaults, logger: NullLogger())
    #expect(store.load() == .standard)
  }
}
