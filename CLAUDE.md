@AGENTS.md

## Claude Code

- Scoped rules in `.claude/rules/` load when you work on matching files; keep them in sync
  with their Cursor twins in `.cursor/rules/`, which link to them.
- Prefer the `make` targets over raw `swift` commands; they include `ee/` exactly like CI.
- Commit with `git commit -s`. Open pull requests as drafts unless asked otherwise.
- Personal preferences belong in `CLAUDE.local.md` (git-ignored), not here.
