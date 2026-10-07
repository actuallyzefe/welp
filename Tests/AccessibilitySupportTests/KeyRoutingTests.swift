import AccessibilitySupport
import AppKit
import Testing

@MainActor
@Suite struct KeyRoutingTests {
  private let app = NSRunningApplication.current

  @Test func acceptsKeysRoutedToTheApp() {
    #expect(app.receivesKeys(routedTo: app.processIdentifier))
  }

  @Test func rejectsKeysRoutedElsewhereEvenWhenTheAppIsFrontmost() {
    // e.g. Return typed into Raycast's panel while the messenger stays frontmost.
    #expect(!app.receivesKeys(routedTo: app.processIdentifier + 1))
  }

  @Test func fallsBackToFrontmostWithoutRoutingInformation() {
    #expect(app.receivesKeys(routedTo: 0) == app.isActive)
  }
}
