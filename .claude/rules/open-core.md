---
paths:
  - "ee/**"
  - "Package.swift"
  - "Makefile"
  - "Sources/WelpApp/Edition.swift"
  - "Sources/WelpApp/AppDelegate.swift"
---

# Open core boundary

The MIT core (`Sources/`, `Tests/`) is a complete app. Welp Pro (`ee/`) is under the
[Welp Commercial License](../../ee/LICENSE) and plugs into the core.

- Dependencies point from `ee/` into the core, never back. No core target may import a
  Pro module, mention a Pro type, or need `ee/` to build.
- Pro extends the core only through `WelpEdition` and `MessengerScreen`. If Pro needs a
  new hook, add a protocol requirement to `WelpEdition` with a no-op in `CoreEdition`.
- Pro adds apps and capabilities; it never removes or limits what the core does.
- The core makes no network requests and has no third-party dependencies. Sparkle and
  licensing live in `ee/`.
- Where a feature belongs: individual safety features → core. Org-facing features
  (managed/locked policies, MDM deployment, reporting, audit) → `ee/`, behind core ports.
- `Package.swift` adds `ee/` targets only inside `if includesPro`. A new Pro target needs
  an explicit `path: "ee/Sources/…"` and its tests `path: "ee/Tests/…"`.
- Verify with `WELP_FOSS_ONLY=1 make test` as well as `make test`.
- Pro strings go in `ee/Sources/WelpProEdition/Resources/Localizable.xcstrings` with
  `bundle: .welpPro`.
- Never weaken license verification (`ee/Sources/Licensing`) or commit keys.
