---
paths:
  - "Sources/SharedKernel/**"
  - "Sources/SendGuard/**"
  - "Sources/GuardedChats/**"
  - "Sources/Preferences/**"
---

# Domain and application modules

These modules hold Welp's rules; they must stay testable without macOS UI or a live app.

- Import only Foundation, CoreGraphics, Observation and inner modules (`SharedKernel`).
  Never AppKit, SwiftUI, ApplicationServices or an adapter module.
- Talk to the outside through ports (`SendTargetScreen`, `ConfirmationPrompt`,
  `SendFeedback`, `GuardedChatLookup`, `GuardedChatRepository`, `AppLogger`). Adapters
  implement them elsewhere.
- No user-facing text: return values (`SendNotice`, `SendAttempt`) that `WelpApp` phrases.
- Fail closed. When in doubt (unknown chat, failed prompt, changed chat or text), don't send.
- Persisted formats are versioned and decoded tolerantly: add a migration and keep reading
  old versions (see `JSONFileGuardedChatRepository`); never drop a user's guarded chats.
- Every behavior change comes with a test in the matching `Tests/<Module>Tests`.
