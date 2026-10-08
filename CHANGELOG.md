# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A notice at the bottom of the settings sidebar while the Accessibility permission is
  missing, with a button to System Settings: Welp can't protect anything without it.

### Changed

- The DMG opens on an install window: Welp next to the Applications folder, with an arrow
  to drag it across.

### Fixed

- The badge above the message box no longer cuts the mode short ("First mess…").

## [1.0.0] - 2026-10-08

The first release.

### Added

- Guard for the official **WhatsApp for Mac** and **Slack** desktop apps: Return and
  Send-button clicks in guarded chats are held before they reach the app.
- Three protection modes per chat: *ask on every message*, *ask on first message*
  (default, with optional re-ask after a period of silence) and *undo* (hold the message
  for a few seconds with an Undo notice).
- Settings window: guarded chats with per-chat modes, one-click protection of the chats
  open right now, behavior and appearance settings, permission status, launch at login.
- Ambient warnings: a badge above the message box and a red menu bar shield while in a
  guarded chat.
- `make diagnose` to show what Welp can see in WhatsApp and Slack.
- Universal (Apple silicon + Intel), Developer ID signed and notarized DMG releases, built
  by a tag-triggered GitHub workflow (`make release` for local builds).
- Open-core repository structure: MIT core, `ee/` reserved for Welp Pro.
- Welp Pro is a yearly subscription: one license key per subscription, confirmed with
  getwelp.io about once a week (only the key is sent). Welp Pro keeps working offline for
  as long as the last confirmation lasts, and stops once the subscription ends.
- English and Turkish interface, following the system or per-app language setting. All texts
  are in one String Catalog, compiled by a SwiftPM build plugin so command-line builds are
  localized too; CI checks that every string is translated and the catalog is up to date.
- Language picker under General: choose Welp's language (or follow the Mac) and restart
  Welp from there. Uses the same setting as System Settings' per-app language.

### Security

- Held sends are replayed only if the chat and the text are unchanged.
- Return presses are matched to the process that actually receives them, so launchers
  such as Raycast or Spotlight never trigger a prompt.

[Unreleased]: https://github.com/actuallyzefe/welp/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/actuallyzefe/welp/releases/tag/v1.0.0
