# Changelog

## 0.1.1

- Preserve existing raw values and exact selections when reconciling unchanged displays, including ambiguous literal masks.
- Keep selected ranges when JS callers omit edit positions; an explicitly supplied start still collapses the caret.
- Add reset() and native form-reset synchronization, respecting canceled resets, invalid defaults, external form controls and teardown; clear field history on successful reset.
- Add regression coverage and Chromium/Firefox/WebKit CI, with separate evidence for each engine.
- Add reviewer navigation and reset controls to all three business demos.

## 0.1.0

- Original MoonBit pattern compiler and immutable structured input editor.
- Atomic insertion/paste, replacement, deletion and UTF-16/scalar mapping.
- Exact decimal editing and Gregorian date validity.
- Reconciliation, stateless JSON protocol, browser composition deferral and bounded history.
- Three interactive scenarios, playground, MoonBit example, independent consumer and CLI replay.
- Cross-target tests, reference models, browser checks, Linux/Windows CI and archive audit.
