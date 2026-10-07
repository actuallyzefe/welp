import Foundation
import SharedKernel

public protocol PreferencesStore {
  func load() -> Preferences
  func save(_ preferences: Preferences) throws
}

/// Keeps preferences as one JSON blob in `UserDefaults`.
public final class UserDefaultsPreferencesStore: PreferencesStore {
  private static let key = "preferences"

  private let defaults: UserDefaults
  private let logger: any AppLogger

  public init(defaults: UserDefaults = .standard, logger: any AppLogger) {
    self.defaults = defaults
    self.logger = logger
  }

  public func load() -> Preferences {
    guard let data = defaults.data(forKey: Self.key) else { return .standard }
    do {
      return try JSONDecoder().decode(Preferences.self, from: data)
    } catch {
      logger.error("Preferences unreadable, using defaults: \(error)")
      return .standard
    }
  }

  public func save(_ preferences: Preferences) throws {
    defaults.set(try JSONEncoder().encode(preferences), forKey: Self.key)
  }
}
