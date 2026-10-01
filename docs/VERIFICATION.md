# Verification methods

Current execution evidence: [Actions](https://github.com/YeeHh2004/mooninput/actions), including screenshots, named browser assertions and coverage artifacts.

| Layer | Verification |
| --- | --- |
| MoonBit | 37 tests: masks, decimals, dates, UTF-16, errors, native reconciliation, limits and protocol; JS and Wasm GC |
| Consumer | Separate module imports public API; registry mode downloads release and compares core sources |
| Generated edits | 12 seeds × 1,000 operations versus an independent digit-array model |
| Exact text | 1,000 seeded long decimals roundtrip without numeric conversion |
| Calendar | 4,800 date samples versus a separate Gregorian reference |
| CLI | Exit codes, exact values, bad arguments and selection-aware replay |
| Browser | 29 checks: typing, paste, select/replace, history, fallback, dates, composition lifecycle, responsive layout and exceptions |
| Reproduction | Example stdout matches on both targets; actual package ZIP is audited |

Composition tests use programmatic events, not all physical IMEs. A 390px screenshot verifies layout, not mobile keyboard compatibility. Random-model testing covers homogeneous digit masks; heterogeneous masks have explicit behavior/error tests.

Coverage measures compiler instrumentation points, not complete semantic coverage:

```sh
moon coverage clean
moon coverage analyze -- -f summary -p YeeHh2004/mooninput
moon coverage report -f cobertura -p YeeHh2004/mooninput -o _build/core-coverage.xml
```

Bug reports should include config, previous raw value, operation, selection and proposed text. CLI replay reproduces a sequence without the surrounding application. Use synthetic data in public reports.
