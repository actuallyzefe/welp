# Security Policy

Welp holds powerful permissions: it can observe keyboard and mouse input through an event
tap and read other apps' interfaces through the Accessibility API. We take reports about
it seriously.

## Supported versions

Only the [latest release](https://github.com/actuallyzefe/welp/releases/latest) gets
security fixes; the official app updates itself, so keep automatic updates on.

## Reporting a vulnerability

**Do not open a public issue.** Report it privately through GitHub:
[Security → Report a vulnerability](https://github.com/actuallyzefe/welp/security/advisories/new).

Please include the affected version or commit, the steps to reproduce, and the impact you
expect. You should receive a first response within 7 days. We will keep you informed while
we work on a fix and credit you in the release notes, unless you prefer otherwise.

## Scope

Especially relevant:

- Message contents leaving the device, being persisted, or appearing in logs
- A guarded send getting through without the configured confirmation, or a held message
  being replayed into a different chat
- Input being blocked, delayed or injected beyond what is needed to guard a send
- Abuse of Welp's Accessibility permission by other processes

Welp Pro's code in `ee/` is in scope as well.

Out of scope: vulnerabilities in WhatsApp, Slack or macOS itself (please report those to
their vendors).
