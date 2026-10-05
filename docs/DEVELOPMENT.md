# Development and release

## Toolchain

Baseline: MoonBit compiler/core `0.10.14+7d59c7ec9`, Node.js 22+. Exact automated installation is in [ci.yml](../.github/workflows/ci.yml), with pinned hustcer/setup-moonbit. General installation: [MoonBit toolchain](https://docs.moonbitlang.com/en/stable/toolchain/index.html). Check `moon version --all`; build.mjs refuses other compiler versions. For a separate installation, set MOON_HOME to its directory and prepend its bin to PATH.

No npm runtime dependency is needed. npm install adds only the pinned browser-test tool. Core imports only the MoonBit standard library.

```sh
moon fmt --check
moon check --target js
moon check --target wasm-gc
moon info
git diff --exit-code -- '*.mbti'
moon test --target js
moon test --target wasm-gc
moon build --target wasm-gc
node scripts/build.mjs
node --test tests/*.test.mjs
node scripts/check-consumer.mjs
node scripts/check-examples.mjs
python scripts/check-mooncake.py
```

The consumer uses a temporary moon.work locally; --registry resolves the published package. Cleanup verifies that the directory belongs directly under the OS temp directory.

## Browser

```sh
npm install
npx playwright install chromium firefox webkit
node tests/browser.mjs
```

Linux CI installs all three engines with --with-deps. Set BROWSER_ENGINE=firefox or webkit to select another engine (default chromium). BROWSER_CHANNEL=msedge can use installed Edge with chromium; PLAYWRIGHT_MODULE can point to an already-installed ESM entry. Screenshots and assertion results include the engine name and go in ignored dist/ and CI artifacts.

`node scripts/serve.mjs` binds 127.0.0.1:4173 (override PORT). Use HTTP, not file://. No backend is needed.

## Structure

- Root .mbt: mask rules, parsing/rendering, editing, dates, decimals, reconciliation.
- protocol/: bounded JSON adapter in MoonBit; bridge/: JavaScript export entry.
- web/: event adapter, three demos and custom-pattern playground.
- cli/: Node IO host using the same engine.
- examples/basic/: runnable MoonBit; examples/consumer/: separate module.
- tests/: Node models/browser checks. MoonBit tests live beside source.

## Publication

.moonignore limits Mooncakes to library/protocol sources, tests, examples and docs. check-mooncake.py inspects the actual ZIP for missing files, credentials, caches and host scripts.

Publish after CI passes for the current commit. Use the [official login/publish process](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html). Keep credentials outside source and logs. Published versions are immutable; bump the version for later source changes.

After publication run `node scripts/check-consumer.mjs --registry` and dispatch registry.yml for Linux/Windows public installation. It uses no publication secret. Pages deploys only successful current-main CI artifacts; build-info.json records source SHA, compiler, version and engine SHA-256. Release archives include tracked source and precompiled site/CLI, checksums and licenses.

From a clean committed checkout, run `node scripts/build.mjs` then `python scripts/release.py`. The script checks the source revision and engine hash, and writes `dist/mooninput-0.1.1.zip` and `dist/SHA256SUMS.txt`. Archive entries have fixed timestamps. Extract it and use `node scripts/serve.mjs` or the CLI without installing MoonBit. Rebuilding still requires the pinned compiler.
