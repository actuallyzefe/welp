import Observation
import SharedKernel

/// The current preferences, observable by the UI and persisted on every change.
@MainActor
@Observable
public final class PreferencesService {
  @ObservationIgnored private let store: any PreferencesStore
  public private(set) var current: Preferences

  public init(store: any PreferencesStore) {
    self.store = store
    self.current = store.load()
  }

  public func update(_ change: (inout Preferences) -> Void) throws {
    var next = current
    change(&next)
    guard next != current else { return }
    try store.save(next)
    current = next
  }
}
