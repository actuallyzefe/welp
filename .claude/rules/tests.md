---
paths:
  - "Tests/**"
  - "ee/Tests/**"
---

# Tests

- Swift Testing only: `import Testing`, `@Test`, `#expect`, `#require`. No XCTest.
- One test target per module (`Tests/<Module>Tests`, Pro's in `ee/Tests/`), depending only on
  that module.
- Use the existing fakes (`Tests/SendGuardTests/Fakes.swift`, `TestChats`) instead of new
  mocks; never touch the live Accessibility API, standard `UserDefaults` or the user's
  files. Use `UserDefaults(suiteName: "welp-tests-<UUID>")` and a temporary directory.
- Name test functions for the behavior they pin down
  (`rejectsKeysRoutedElsewhereEvenWhenTheAppIsFrontmost`), not the method under test.
- Test data uses made-up chat names and texts, never real conversations.
- Run `make test`; for core tests also `WELP_FOSS_ONLY=1 make test`.
