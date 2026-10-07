---
paths:
  - "Sources/WelpApp/**"
  - "ee/Sources/WelpProEdition/**"
---

# App layer and UI

- `WelpApp` is the composition root: it wires adapters to ports and turns domain values
  into text. Keep rules out of it; they belong in `SendGuard` or `GuardedChats`.
- Colors: only `Theme.ink`, `Theme.signal` (guarded, warnings) and `Theme.brand` (main calls
  to action), plus the derived tokens in `Theme.swift`. Prefer native controls, which bring
  their own colors. No hard-coded colors in views.
- Liquid Glass via `glassSurface(in:)`, which falls back on macOS 14 and 15. Guard newer
  APIs with `#available`.
- In the *Are you sure?* prompt, `Return` sends (the prompt itself is the pause) and
  `Escape` cancels. A `Return` within `minimumReadingTime` of the prompt appearing, or a
  key repeat, is ignored, so a double press or a held key never sends.
- Everything that touches AppKit or SwiftUI is `@MainActor`.
- Preview UI without real data: `swift build && .build/debug/Welp --render-settings ./shots`.
  After a visible change, run `make screenshots` and include before/after images in the PR.

## Localization

- Every user-facing string: `String(localized: "…", bundle: .localization, comment: "…")`
  (`bundle: .welpPro` in `ee/`). Never `Bundle.module`; it breaks in the signed app.
- The comment tells translators where the text appears and what each placeholder is.
- Interpolate whole sentences. Never concatenate fragments or add an "s" for plurals; the
  catalog's plural forms handle numbers. Format numbers, dates and durations with
  `FormatStyle`.
- `Text(verbatim:)` for text that must not be translated, such as the app name.
- After adding or removing strings, run `make strings`, then translate the new entries into
  every language in `Support/Info.plist` (`CFBundleLocalizations`). `make test` fails on
  missing translations or changed placeholders.
- Logs and `make diagnose` output stay in English.
