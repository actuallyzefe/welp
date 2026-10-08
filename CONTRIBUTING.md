# Contributing to Welp

Thanks for helping! Welp is small on purpose; this guide keeps it that way.

## Before you start

- **Bugs:** search [existing issues](https://github.com/actuallyzefe/welp/issues) (open
  and closed) first. Use the bug report template and include your macOS, Welp, WhatsApp
  and/or Slack versions.
- **WhatsApp or Slack changed its UI?** These are the most valuable contributions. Run
  `make diagnose` (its output includes the text in the message box; remove it before
  sharing), update `WhatsAppIdentifiers.swift` or `SlackIdentifiers.swift` (in
  `ee/`, see [License of contributions](#license-of-contributions)), and mention the app
  version you verified with.
- **New features:** open an issue to discuss before writing code, so you know up front
  whether it fits. Welp should stay simple; we may say no to good ideas.
- **Security issues:** never in public issues. See [SECURITY.md](SECURITY.md).

## Development setup

Requirements: macOS 14+, Xcode 16.3+ (Xcode 26 to build the Liquid Glass look). Welp Pro (`ee/`) uses Sparkle, fetched by SwiftPM.

```bash
make build        # debug build
make test         # unit tests
make lint         # swift format lint --strict (make format fixes it)
make app          # signed build/Welp.app (the official app, with Welp Pro)
make install      # make app, then copy it to /Applications and open it
make diagnose     # print what Welp sees in WhatsApp and Slack
make screenshots  # render the README screenshots in every language
make strings      # sync the String Catalogs with the code
```

`make app` signs with the first *Apple Development* or *Developer ID* identity in your
keychain (override with `CODESIGN_IDENTITY=...`). Keep it stable: macOS ties the
Accessibility permission to the signature, so after switching identities, toggle Welp off
and on in System Settings → Privacy & Security → Accessibility.

The repository has two parts: the open-source core (MIT) and Welp Pro in [`ee/`](ee/)
(its own [license](ee/LICENSE)). By default everything is built;
set `WELP_FOSS_ONLY=1` (e.g. `WELP_FOSS_ONLY=1 make test`) to work on the core alone,
exactly as people who build without `ee/` will get it.

To try your changes, install the app (`make install`) and grant it the Accessibility
permission. Logs are in Console.app, subsystem `dev.karakanli.welp`. To review UI changes without real data:
`swift build && .build/debug/Welp --render-settings ./shots`. After a visible UI change,
`make screenshots` updates the README images in every language.

## Code guidelines

- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Keep dependencies pointing inward;
  `SendGuard` and `GuardedChats` must stay free of AppKit and Accessibility code.
- Match the surrounding style; `make format` applies the project's `swift format` rules.
- Swift 6 strict concurrency, no warnings.
- Business rules come with tests (Swift Testing). Adapters that need a live app should be
  verified with `make diagnose` and described in the pull request.
- Never log or persist message contents.
- UI: stay within the three theme colors in `Theme.swift`.
- Every user-facing string is localized; see [Translations](#translations).

## Translations

Welp's interface is in English (the source language) and Turkish. The core's texts live in
[`Sources/WelpApp/Resources/Localizable.xcstrings`](Sources/WelpApp/Resources/Localizable.xcstrings)
and Welp Pro's in [`ee/Sources/WelpProEdition/Resources/Localizable.xcstrings`](ee/Sources/WelpProEdition/Resources/Localizable.xcstrings).
Edit them in Xcode or as JSON.

**Adding a language** (no code changes needed):

1. Add its code (e.g. `de`) to `CFBundleLocalizations` in [`Support/Info.plist`](Support/Info.plist).
2. Translate every string in both catalogs. Open `Package.swift` in Xcode and use the
   catalog editor, or add a `"de"` entry next to each `"tr"` one in the JSON. For strings
   with a number, translate every plural form your language uses.
3. `make test`. It fails on any missing, unreviewed or empty translation and on
   translations that change the `%@` / `%lld` placeholders. Use positional placeholders
   (`%1$@`, `%2$@`) when your language needs a different word order.

**Writing code:**

- Write UI texts in English with a comment for translators, so they know where the text
  appears and what the placeholders are:

  ```swift
  String(
    localized: "Sending to \(chat)…", bundle: .localization,
    comment: "Undo toast. The argument is a chat name.")
  ```

  Always pass `bundle: .localization` (in `ee/`: `bundle: .welpPro`); SwiftPM's
  `Bundle.module` does not work inside the signed app. Use `Text(verbatim:)` for text that must not be translated (the app name).
- Never build sentences from pieces or add an "s" for plurals; interpolate the number and
  let the catalog's plural forms handle it. Format durations, dates and numbers with
  `FormatStyle` (they follow the user's language and region).
- Keep domain modules free of UI text: return a value such as `SendNotice` and turn it into
  text in `WelpApp`.
- Run `make strings` to add new strings to the catalogs (and mark removed ones stale), then
  translate them. CI runs `make check-strings` and fails if a catalog is out of date.
- Diagnostics (`make diagnose`) and logs stay in English; they are meant for issues.

## Pull requests

- One topic per pull request, with a clear description and, for UI changes, screenshots.
- `make lint` and `make test` must pass; CI runs both.
- **AI-assisted contributions are welcome**, but you must understand and be able to
  explain every change you submit. Disclose the tools you used in the pull request
  template.
  Coding agents pick up [AGENTS.md](AGENTS.md) and the scoped rules in `.claude/rules/`
  and `.cursor/rules/`; keep them in step with this guide.

## Branches and commits

- Branch from `main` and name it `<type>/<short-topic>`, e.g. `fix/slack-send-button`,
  `feat/telegram-support`. Never push to `main` directly.
- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`,
  `docs:`, `refactor:`, `perf:`, `test:`, `build:`, `ci:`, `chore:`, `revert:`. Add `!`
  for breaking changes (`feat!: …`).
- Pull requests are squash-merged, so the **PR title** becomes the commit on `main` and
  must follow the same format; CI checks it. Commits inside your branch can be anything.
- Rebase on `main` instead of merging `main` into your branch.

## Releases (maintainers)

Releases are universal (Apple silicon + Intel), signed with a Developer ID certificate and
notarized by Apple, so they open without Gatekeeper warnings.

1. Write the release notes in `docs/releases/1.0.0.md`, for users: they appear in the
   app's update window and on the GitHub release. Move the `[Unreleased]` entries in
   [CHANGELOG.md](CHANGELOG.md) under the new version.
2. Tag and push: `git tag v1.0.0 && git push origin v1.0.0`.
3. The [Release workflow](.github/workflows/release.yml) builds `Welp-1.0.0.dmg`, notarizes
   it and attaches it to a **draft** GitHub release, together with a copy named `Welp.dmg`. Check it, then
   publish the draft: the website's download link
   (`releases/latest/download/Welp.dmg`) and the app's update feed
   (`releases/latest/download/appcast.xml`) point to the newest published release.

The workflow runs in the `release` environment and needs these secrets:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_P12` | Developer ID Application certificate + private key, exported as `.p12`, base64 |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password of that `.p12` |
| `NOTARY_KEY_P8` | App Store Connect API key (`.p8` contents, *Developer* role) |
| `NOTARY_KEY_ID` | Key ID of that API key |
| `NOTARY_ISSUER` | Issuer ID shown on the App Store Connect API keys page |
| `SPARKLE_PRIVATE_KEY` | Sparkle's EdDSA private key, exported with `generate_keys -x` |

The DMG's install window (background, icon positions) lives in `Support/DMG`; `make dmg`
builds an unsigned one to check it.

To release from your own Mac instead, store notarization credentials once with
`xcrun notarytool store-credentials welp` and run `make release VERSION=1.0.0`.

## License of contributions

- **Core** (everything outside `ee/`): your contributions are licensed under the
  [MIT License](LICENSE).
- **Welp Pro** ([`ee/`](ee/)): contributions are welcome too, and fall under the
  [Welp Commercial License](ee/LICENSE): you may publish patches, and the licensor keeps
  all rights to them.

### Developer Certificate of Origin

Instead of a contributor license agreement, Welp uses the
[Developer Certificate of Origin](https://developercertificate.org/) (DCO): by signing off
a commit you certify that you wrote it or have the right to submit it under the license of
the part it changes. Sign off every commit with `git commit -s`, which adds:

```
Signed-off-by: Your Name <you@example.com>
```
