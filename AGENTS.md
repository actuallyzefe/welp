# Welp: guide for AI coding agents

Welp is a macOS menu bar app that asks *"Are you sure?"* before a message is sent to a
guarded chat in the official WhatsApp and Slack desktop apps. Swift 6, SwiftPM, AppKit +
SwiftUI, macOS 14+. It is **open core**: the MIT core in `Sources/`, Welp Pro in `ee/`
under its own license.

This file is for agents (Claude Code, Cursor, Codex, …). Humans: read
[CONTRIBUTING.md](CONTRIBUTING.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); they
are the source of truth and this file only distills them. Scoped rules live in
[`.claude/rules/`](.claude/rules/) and [`.cursor/rules/`](.cursor/rules/).

## Commands

```bash
make build                   # debug build (core + ee/)
make test                    # unit tests (Swift Testing)
WELP_FOSS_ONLY=1 make test   # the core alone, exactly as people without ee/ build it
make lint                    # swift format lint --strict; `make format` fixes it
make strings                 # sync the String Catalogs with the code
make check-strings           # what CI runs: fails if a catalog is out of date
make diagnose                # what Welp sees in WhatsApp and Slack (needs the live apps)
```

`make app`, `make install`, `make run`, `make release` sign the app, replace
`/Applications/Welp.app` or notarize: don't run them unless asked.

## Before you say you're done

1. `make lint` and `make test` pass.
2. `WELP_FOSS_ONLY=1 make test` passes when you touched `Package.swift`, `WelpApp` or `ee/`.
3. `make check-strings` passes when you touched a user-facing string.
4. No new compiler warnings (Swift 6 strict concurrency).

Say plainly what you couldn't verify, e.g. adapter changes that need the live app.

## Map

```
Sources/SharedKernel          ChatName, ChatID, Messenger, ProtectionMode, AppLogger
Sources/GuardedChats          which chats are guarded, and how
Sources/SendGuard             the business rule: policy + coordinator, ports only
Sources/Preferences           app-wide settings
Sources/AccessibilitySupport  AXElement, key routing helpers
Sources/WhatsAppAccessibility WhatsApp adapter
Sources/InputInterception     CGEventTap
Sources/WelpApp               composition root, menu bar, SwiftUI settings, WelpEdition
ee/Sources/…                  Slack adapter, Licensing, WelpProEdition, WelpPro executable
```

## Do

- Keep dependencies pointing inward. `SendGuard`, `GuardedChats`, `SharedKernel` and
  `Preferences` never import AppKit, SwiftUI or ApplicationServices.
- Extend through ports: a new messenger is one adapter module (a `MessengerScreen`) returned
  from an edition; Pro features plug in through `WelpEdition`.
- Fail closed: unknown chat → ask; prompt failure → don't send; changed chat or text →
  don't replay.
- Write business rules with tests (Swift Testing: `import Testing`, `@Test`, `#expect`).
- Localize every user-facing string with a translator comment and the right bundle
  (`.localization` in the core, `.welpPro` in `ee/`).
- Match the surrounding code: 2-space indent, 100 columns, doc comments that say *why*.
- Keep changes small and on one topic; split refactors from features.

## Don't

- Never log, persist or send message contents. Not in logs, tests, diagnostics or errors.
- Never make the core depend on `ee/`, or add network access to the core.
- Never let Pro limit what the core does; Pro only adds.
- Never inject into or modify WhatsApp or Slack; read them through Accessibility only.
- Never block the event tap: bounded AX calls, node-capped tree searches.
- Never use `try!` or add third-party dependencies to the core.
- Never put UI text in domain modules; return a value (`SendNotice`) and phrase it in `WelpApp`.
- Never edit `.xcstrings` keys by hand to add strings; run `make strings`.

## Writing clean code

The bar is the existing code; `SendGuardPolicy` and `SendGuardCoordinator` are good models.

- **Names from the domain.** Use the words the product uses: chat, guarded, send attempt,
  protection mode, held send. Types are nouns, methods read as phrases
  (`protection(for:)`, `hasAnyGuarded(in:)`), Booleans read as assertions (`isAvailable`).
- **Make illegal states unrepresentable.** Prefer enums with associated values
  (`SendDecision`) and validated value types (`ChatName` fails on empty input) over flags
  and raw strings. Switch exhaustively; no `default:` on our own enums, so a new case
  breaks the build where it must be handled.
- **Value types first.** `struct` and `enum` by default; `final class` only for identity or
  shared mutable state. No subclassing.
- **Exit early.** `guard` for preconditions, so the happy path stays unindented. Short
  functions that do one thing; extract a helper when a block needs a comment to explain it.
- **Inject dependencies through `init`**, including time and scheduling (`clock:`,
  `schedule:`), with production defaults. No singletons or globals in testable code.
- **Narrow access.** `private` by default, `public` only for what another module uses.
- **Concurrency is explicit.** `@MainActor` for UI and Accessibility state, `Sendable` for
  values that cross isolation. No `@unchecked Sendable` or `nonisolated(unsafe)` without a
  comment saying why it is safe.
- **Errors are typed.** A small `Error` enum per module (`GuardedChatsError`); never swallow
  an error silently. Log it (without message contents) or surface it.
- **No force unwraps in production code** (`!`, `as!`); fine in tests for known-good fixtures.
- **Comments say why, not what.** Doc-comment every public type and non-obvious public
  member; skip comments that restate the code. No commented-out code, no `TODO`s: open an
  issue instead.
- **No speculative generality.** No protocol with a single conformer unless it is a port,
  no options nobody asked for, no dead code. Delete what a change makes unused.
- **Small, focused diffs.** Don't reformat or rename unrelated code in the same change.

## Git and pull requests

- Branch `<type>/<short-topic>` from `main`; never push to `main`.
- [Conventional Commits](https://www.conventionalcommits.org/): `feat`, `fix`, `docs`,
  `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`; `!` for breaking.
  PRs are squash-merged, so the **PR title** is the commit on `main`; CI checks it.
- Sign off every commit (`git commit -s`, [DCO](https://developercertificate.org/)).
- Fill in [the PR template](.github/pull_request_template.md), including the
  AI-assistance section.
- Add user-facing changes to `CHANGELOG.md` under **Unreleased**.
