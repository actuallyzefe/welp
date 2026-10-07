---
paths:
  - "Sources/AccessibilitySupport/**"
  - "Sources/WhatsAppAccessibility/**"
  - "Sources/InputInterception/**"
  - "Sources/WelpApp/ConversationMonitor.swift"
  - "Sources/WelpApp/MessengerScreen.swift"
  - "ee/Sources/SlackAccessibility/**"
---

# Messenger adapters and input interception

- **Read, never modify.** Messengers are only read through the Accessibility API. Nothing
  is injected; replay presses the send button only after re-checking chat and text.
- **UI assumptions live in one file per messenger** (`WhatsAppIdentifiers.swift`,
  `SlackIdentifiers.swift`). Put new roles, identifiers and titles there.
- **Never block input.** The event tap answers synchronously. Set the messaging timeout
  (0.25 s) on every element you query, keep tree searches node-capped (`maxNodes`), and
  query nothing while no chat in that messenger is guarded.
- **Follow the key, not the frontmost app.** Decide from the window server's routing of
  the event, so launchers like Raycast or Spotlight never trigger a prompt.
- **Privacy.** Message text is read only at send time, compared, then dropped. Never log
  it, store it, or put it in an error. `make diagnose` output is the only exception, and it
  says so.
- Pure parsing (window titles, key routing) gets unit tests. Anything that needs the live
  app: verify with `make diagnose` and the real app, and say in the PR which app versions.
- A new messenger: one module, one `MessengerScreen`, returned by an edition
  (`AppDelegate.makeScreens(edition:)` for the core, `ProEdition.makeScreens` for Pro).
