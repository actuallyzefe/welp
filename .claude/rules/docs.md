---
paths:
  - "README.md"
  - "README.*.md"
  - "CHANGELOG.md"
  - "CONTRIBUTING.md"
  - "docs/**"
---

# Docs and changelog

- `README.md` is for users: what Welp does, install, usage, privacy, known issues. Build
  and internals go in `CONTRIBUTING.md` and `docs/ARCHITECTURE.md`.
- Every README change is mirrored in `README.tr.md` (Turkish, with Turkish screenshots in
  `docs/images/tr/`).
- `CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Add
  user-facing changes under **Unreleased**. Don't add *Fixed* entries for bugs in features
  that were never released.
- Release notes (`docs/releases/<version>.md`) are for users; they appear in the update
  window and on the GitHub release.
- When code changes a module, a dependency or a design rule, update
  `docs/ARCHITECTURE.md` and the diagram in `Package.swift` in the same PR.
- Plain, short sentences. No marketing words.
