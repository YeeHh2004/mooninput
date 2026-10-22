# Verification methods

Current execution evidence: [Actions](https://github.com/YeeHh2004/mooninput/actions), including screenshots, named browser assertions and coverage artifacts.

| Layer | Verification |
| --- | --- |
| MoonBit | 110 tests across legacy masks and extensible families: dynamic dispatch, named composition, optional/repeat, regex, callbacks, locale numbers/dates, presentation, UTF-16, strict snapshot restoration, errors and resource limits; JS and Wasm GC |
| Consumer | Separate module adds 4 consumer tests and imports old and new public APIs; registry mode downloads the version and compares root/protocol source files before testing both backends |
| Generated edits | 12 seeds × 1,000 operations versus an independent digit-array model |
| Exact text | 1,000 seeded long decimals roundtrip without numeric conversion |
| Calendar | 4,800 date samples versus a separate Gregorian reference |
| Regular languages | 3,906 finite-language candidates versus an independent word oracle; finite regex/composite models and bounded nested repetition |
| Bounded numbers | 1,000 range values and 401 signed integer-cent inputs versus independent arithmetic references |
| CLI / protocol / adapter | 30 Node tests cover exit codes, exact values, bad arguments, selection-aware replay, previous-display transport, rejected restore/update state and nested option guards |
| Browser | 91 checks per engine (36 base + 39 advanced + 16 acceptance) run on Chromium, Firefox and WebKit: dynamic selection, regex prefixes, field composition, custom tokens, numeric/date options, workbench presets, errors, history, option updates/events, lifecycle recovery and responsive layout; execution evidence and assertion names are in each result artifact |
| Reproduction | Example stdout matches on both targets; actual package ZIP is audited |

Clipboard payloads and composition tests use programmatic events; they do not exercise OS clipboard permissions or all physical IMEs. A 390px screenshot verifies layout, not mobile keyboard compatibility. WebKit CI is not a claim of testing actual iOS devices. The 12,000-edit random model covers homogeneous digit masks; composition, dynamic and heterogeneous paths have separate finite-language, exhaustive and regression checks. Each engine writes dist/browser-ENGINE-results.json, dist/advanced-ENGINE-results.json and dist/acceptance-ENGINE-results.json. CI uploads these named checks and screenshots in verification-evidence; use the matching commit's actual run rather than inferring a result from the test count.

The 0.2.1 regressions exercise validated raw/display snapshot roundtrips, ambiguous composite history and same-raw replacement, native reset selection recovery, full-field bounds after numeric fragment pasting, whole-input preparation ordering, numeric date suffixes, nested numeric/date updateOptions protection, UTF-16-constrained regex continuations and composite search-budget fallback without truncation. Core checks and tests use the pinned compiler/core0.10.14+7d59c7ec9; the committed CI workflow is the reproducible execution definition.

Coverage measures compiler instrumentation points, not complete semantic coverage:

```sh
moon coverage clean
moon coverage analyze -- -f summary -p YeeHh2004/mooninput
moon coverage report -f cobertura -p YeeHh2004/mooninput -o _build/core-coverage.xml
```

Bug reports should include config, previous raw and display values, operation, selection and proposed text. CLI replay reproduces a sequence without the surrounding application. Use synthetic data in public reports.
