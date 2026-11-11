# Originality, references and tooling

MoonInput is an original, AI-assisted implementation, copyright 2026 YeeHh2004, under MIT. It is not an IMask, Maskito, Cleave.js or MoonForm port and makes no compatibility claim. No source from those projects was copied.

- Conceptual reference: [IMask guide](https://imask.js.org/guide.html), covering dynamic candidates, custom validation, composition, regex/function/range/enum rules, presentation and model/view responsibilities. This project's implementation, API and tests follow its own documented contract; its portable NFA and rule engine were written in MoonBit rather than importing JavaScript source. The [feature comparison](docs/IMASK-COVERAGE.md) records supported scope and differences.
- Ecosystem comparisons in [SELECTION](docs/SELECTION.md) are not dependencies or incorporated code.
- Runtime dependency: MoonBit standard library, primarily Apache-2.0 with adapted-component notices. Compiled output includes core code. The verified baseline distribution's full [LICENSE](licenses/MoonBit-core-LICENSE) and [NOTICE](licenses/NOTICE) are retained, including notices for components not necessarily linked in this build. Generated web/release output takes these notices from the actual active toolchain core so builds with another compiler do not silently ship outdated notices.
- Tools: MoonBit compiler/core 0.10.20+65efd5b93, Node.js, Playwright 1.62.1 (Apache-2.0, test only). No external UI framework or font is loaded.
- Browser/release distributions include MIT and complete upstream notices. Screenshots capture this project.

Where a competition requires entrant-written application prose, an AI-assisted reference draft must be revised/written by the entrant and must not be represented as human-authored unchanged.
