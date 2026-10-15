# Verification methods

Current execution evidence: [Actions](https://github.com/YeeHh2004/mooninput/actions), including screenshots, named browser assertions and coverage artifacts.

| Layer | Verification |
| --- | --- |
| MoonBit | 90 tests across legacy masks and extensible families: dynamic dispatch, named composition, optional/repeat, regex, callbacks, locale numbers/dates, presentation, UTF-16, errors and resource limits; JS and Wasm GC |
| Consumer | Separate module imports old and new public APIs; registry mode downloads the version and compares root/protocol source files before testing both backends |
| Generated edits | 12 seeds × 1,000 operations versus an independent digit-array model |
| Exact text | 1,000 seeded long decimals roundtrip without numeric conversion |
| Calendar | 4,800 date samples versus a separate Gregorian reference |
| Regular languages | 3,906 finite-language candidates versus an independent word oracle; finite regex/composite models and bounded nested repetition |
| Bounded numbers | 1,000 range values and 401 signed integer-cent inputs versus independent arithmetic references |
| CLI | Exit codes, exact values, bad arguments and selection-aware replay |
| Browser | 36 existing checks plus 39 advanced checks per engine (Chromium, Firefox, WebKit): dynamic selection, regex prefixes, field composition, custom tokens, numeric/date options, workbench presets, errors, history, option updates/events and responsive layout |
| Reproduction | Example stdout matches on both targets; actual package ZIP is audited |

Clipboard payloads and composition tests use programmatic events; they do not exercise OS clipboard permissions or all physical IMEs. A 390px screenshot verifies layout, not mobile keyboard compatibility. WebKit CI is not a claim of testing actual iOS devices. The 12,000-edit random model covers homogeneous digit masks; composition, dynamic and heterogeneous paths have separate finite-language, exhaustive and regression checks. Each engine writes its own existing/advanced results and screenshots; current run results are in Actions, rather than inferred from a test count.

Coverage measures compiler instrumentation points, not complete semantic coverage:

```sh
moon coverage clean
moon coverage analyze -- -f summary -p YeeHh2004/mooninput
moon coverage report -f cobertura -p YeeHh2004/mooninput -o _build/core-coverage.xml
```

Bug reports should include config, previous raw value, operation, selection and proposed text. CLI replay reproduces a sequence without the surrounding application. Use synthetic data in public reports.
