# Behavior contract

## Core

The core owns formatted display, canonical raw text, selection mappings and edit transitions. Browser code supplies events and DOM selection; it does not implement formatting rules.

All public selection positions are UTF-16 offsets, matching HTML input selection APIs on every compilation target. Offsets inside a surrogate pair snap to scalar boundaries. Grapheme-cluster navigation is not promised. Input sizes are bounded to prevent accidental huge allocations.

Pattern slots: `#` ASCII digit, `A` ASCII letter normalized to uppercase, `*` ASCII alphanumeric normalized to uppercase, `X` printable Unicode scalar. Other characters are literals; backslash escapes syntax. A single trailing `[optional suffix]` is supported. Literal characters are displayed only when followed by populated content, so partially typed fields do not acquire dangling separators.

The editor accepts formatted paste and raw paste. Each proposed replacement is evaluated atomically; invalid characters or excess input return a typed error and preserve the previous editor. No silent truncation. Literal deletion removes an adjacent editable value, and caret positions always remain within the displayed string.

Decimal input retains exact text (no floating-point roundtrip), supports optional sign, configurable fractional precision and grouping. Intermediate `-`, `.`, and `-.` remain editable and are reported incomplete. Completion normalizes a leading decimal point but does not silently round digits.

ISO date input uses `####-##-##`, with complete-value Gregorian calendar validation. A syntactically editable but invalid complete date remains visible and is reported invalid rather than silently changed.

## Browser boundary

The adapter handles beforeinput, paste, selection, composition and fallback input events. It defers normalization until composition ends. Its local edit history supports browser undo/redo for intercepted edits. The pure core is usable without this adapter.

Core targets: JavaScript and Wasm GC. Browser adapter target: JavaScript. No claims of native widgets, all mobile IMEs, universal telephone validation or full locale-number parsing.

## Verification

Unit examples, state-machine invariants, random edit sequences against simple models, cross-target replay, browser event tests, and an independently installed consumer verify the public behavior. Published claims must describe measured results.
