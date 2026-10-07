# Architecture

Welp is a **modular monolith**: one app, split into Swift Package targets with explicit
dependencies. Module boundaries are enforced by the compiler — a module cannot import
another one it does not declare in `Package.swift`.

## Modules

The repository holds two parts: the open-source core in `Sources/` (MIT) and Welp Pro in
`ee/` (Welp Commercial License). The core is a complete app; Welp Pro plugs into it.

```
Sources/                     Open-source core (MIT)
├── SharedKernel/            ChatName, ChatID, Messenger, ProtectionMode, AppLogger
├── GuardedChats/            Which chats are guarded, and how
│   ├── Domain/              GuardedChat, GuardedChatList, GuardedChatRepository (port)
│   ├── Application/         GuardedChatsService (@Observable use cases)
│   └── Infrastructure/      JSON repository: atomic writes, v1/v2 → v3 migration,
│                            corrupt-file quarantine
├── SendGuard/               The business rule; knows nothing about macOS or messengers
│   ├── Domain/              SendGuardPolicy (three modes), ApprovalMemory, GuardBehavior,
│   │                        SendAttempt, SendContext, ConfirmationMessage
│   └── Application/         SendGuardCoordinator (ask / hold / replay), ports
├── Preferences/             App-wide settings (UserDefaults, tolerant decoding)
├── AccessibilitySupport/    AXElement, WindowOwnerLocator, key routing helpers
├── WhatsAppAccessibility/   WhatsApp adapter (SendTargetScreen)
├── InputInterception/       CGEventTap at the annotated session level
├── WelpApp/                 Composition root, menu bar, SwiftUI settings, overlays;
│                            defines the WelpEdition extension point
└── Welp/                    The core's executable: WelpApp with CoreEdition

ee/Sources/                  Welp Pro (Welp Commercial License)
├── SlackAccessibility/      Slack adapter (SendTargetScreen) for the Electron app
├── Licensing/               Ed25519-signed license keys and subscription leases
├── WelpProEdition/          ProEdition: adds Slack when licensed, plan settings,
│                            upgrade prompt; its own String Catalog
└── WelpPro/                 The official app's executable: WelpApp with ProEdition
```

```
Welp ─────▶ WelpApp ──▶ Preferences ──────────────────────────────────┐
                │─────▶ GuardedChats ─────────────────────────────────┤
                │─────▶ WhatsAppAccessibility ─┬─▶ SendGuard ─────────┼──▶ SharedKernel
                │                              └─▶ AccessibilitySupport
                └─────▶ InputInterception (standalone)

WelpPro ──▶ WelpProEdition ──▶ WelpApp, Licensing, SlackAccessibility (──▶ SendGuard, …)
```

Dependencies only point from `ee/` into the core. `Package.swift` leaves `ee/` out when it
is missing or `WELP_FOSS_ONLY=1` is set, and CI builds and tests the core that way too.

## Flow of a send

1. **`InputInterceptor`** sees every `Return` and left click in the session, at the
   *annotated* level where the window server has already decided which process receives
   the event. It must answer synchronously: pass or swallow.
2. **`SendGuardCoordinator`** asks the messenger screens (through
   `CompositeSendTargetScreen`) whether the gesture is a send, and to which chat.
3. **`SendGuardPolicy`** decides: allow, allow (already approved this visit), confirm, or
   delay for undo.
4. For a held send, the coordinator shows the prompt (`ConfirmationPrompt`) or the undo
   toast (`SendFeedback`) asynchronously, then calls the target's **`replay`**, which
   re-checks the chat and text before pressing the send button.

`ConversationMonitor` polls the frontmost messenger a few times per second (only while one
is frontmost) to keep the approval memory, the composer badge and the menu bar shield in
sync with the chat you are in.

## Design rules

- **Ports and adapters.** `SendGuard` defines ports (`SendTargetScreen`,
  `ConfirmationPrompt`, `SendFeedback`, `GuardedChatLookup`); adapters live in their own
  modules or in `WelpApp`. Supporting a new messenger means writing one adapter module
  (a `MessengerScreen`) and returning it from an edition: the core's in
  `AppDelegate.makeScreens(edition:)`, Welp Pro's in `ProEdition.makeScreens`.
- **Editions.** `WelpEdition` is how Welp Pro extends the core: extra messengers, whether
  each one is available (`GuardedChatsService` takes that as `isAvailable`), the upgrade
  prompt and the plan settings. The core ships `CoreEdition` (WhatsApp only).
- **Fail closed.** Unknown chat → ask. Prompt failure → do not send. Changed chat or text
  → do not replay.
- **Follow the key, not the frontmost app.** Launchers such as Raycast or Spotlight take
  the keyboard while a messenger stays frontmost; the window server's routing decides
  whether a `Return` is a send.
- **Read, never modify.** Messengers are only read through the Accessibility API; nothing
  is injected into them. In Slack, edits aren't guarded (an edit can't change where a
  message went) and the badge appears only while the message box is focused, to avoid
  scanning its large UI tree.
- **Never block input.** Event tap work is bounded: Accessibility calls time out after
  250 ms, tree searches are node-capped, and nothing is queried while no chat is guarded.
- **Text belongs to the app layer.** Domain modules return values (`SendNotice`,
  `SendAttempt`); `WelpApp` turns them into localized text from its String Catalog
  (`Resources/Localizable.xcstrings`, compiled by the `StringCatalogCompiler` plugin).
- **UI assumptions live in one file per messenger** (`WhatsAppIdentifiers`,
  `SlackIdentifiers`), so app updates are cheap to follow.

## Open core boundary

Welp Pro lives under [`ee/`](../ee/) ([its own license](../ee/LICENSE)):

- The core always builds and works without `ee/` (`WELP_FOSS_ONLY=1`); CI checks it.
- Dependencies point from `ee/` into the core, never back: Pro plugs in through
  `WelpEdition` and `MessengerScreen`.
- Pro adds apps and capabilities; it never limits what the core does.
