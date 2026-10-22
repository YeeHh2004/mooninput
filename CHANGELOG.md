# Changelog

## 0.2.1

- Add `Editor::restore(mask, raw, display, start, end)` with strict revalidation of snapshot text and selection. Optional display transport in the JSON protocol preserves explicitly formatted composite partitions across requests and browser history.
- Make browser history track semantic state changes, validate restores before moving history entries, and retain existing state after failed programmatic updates. Failed native form resets also restore the selection captured before the browser's reset action. Protect complete canonical values during option changes involving numeric/date rules, including nested rules.
- Normalize formatted numeric fragments before insertion/overwrite through validation/value/presentation wrappers, without clamping an isolated fragment against whole-field bounds. Keep whole-input preparation ordering and existing pattern overwrite counting. Keep date raw digits intact when a format has a numeric literal suffix.
- Preserve the existing composite partition when replacement text produces the same raw content.
- Preserve fully consumed editable composite results when the bounded search budget expires; impossible overflow still fails.
- Enforce regex continuation feasibility against both scalar and UTF-16 limits, reject unpaired surrogates, and bound mixed-limit continuation analysis.
- Add core, protocol, Node and browser acceptance regressions; CI runs the acceptance suite on Chromium, Firefox and WebKit and uploads separate results per engine. Scope remains a documented MoonBit implementation rather than an IMask compatibility claim.

## 0.2.0

- Generalize the MoonBit engine with dynamic named candidates and dispatch, function masks, custom pattern tokens, validation/preparation/value hooks, named nested composite blocks, optional blocks, literals and finite repetition.
- Add portable bounded NFA regex masks with viable-prefix editing and inferred finite capacity; add range and enumeration masks.
- Add configurable exact decimal separators, mappings, string bounds, zero policies and autofix; configurable Gregorian date ordering, literals and bounds.
- Add placeholders, eager pattern literals, visual concealment, explicit completion hooks, overwrite/skip modes, pure pipes and rule replacement.
- Extend the stateless JSON boundary, Node CLI and browser adapter with declarative rule trees, option updates and accept/complete events.
- Add six configurable browser examples, ten workbench presets, native MoonBit callback examples and independent consumer checks.
- Fix cross-rule raw/canonical isolation, semantic-invalid composite editing, hidden-display native edits, formatted overwrite widths and no-op ambiguous segmentation.
- Expand JS/Wasm, independent language/number models and three-engine browser verification. Document exact scope against IMask rather than claiming JavaScript API compatibility.

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
