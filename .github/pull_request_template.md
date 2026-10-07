## What and why

<!-- What does this change, and why? Link the issue: Closes #123 -->

## How I verified it

- [ ] `make lint` and `make test` pass
- [ ] `WELP_FOSS_ONLY=1 make test` passes too (the core builds without `ee/`)
- [ ] Tested in the real app (`make install`), with: <!-- WhatsApp / Slack versions -->
- [ ] UI changes include before/after screenshots (`.build/debug/Welp --render-settings`)

## AI assistance

<!-- Tools used (or "none"), and what you verified yourself. -->

- [ ] I understand every change in this pull request and can explain it without a model's help.

## Checklist

- [ ] No message contents are logged or persisted
- [ ] `CHANGELOG.md` updated under **Unreleased** for user-facing changes
- [ ] My commits are signed off (`git commit -s`, [DCO](https://developercertificate.org/)): changes outside `ee/` under the MIT License, changes in `ee/` under the [Welp Commercial License](../ee/LICENSE)
