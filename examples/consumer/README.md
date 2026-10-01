# Independent consumer

This is a separate MoonBit module, not an internal package. After installing the pinned compiler:

```sh
cd examples/consumer
moon update
moon test --target js
moon test --target wasm-gc
moon run . --target wasm-gc
```

Expected output: `AB-1234`, then `AB1234`.

From the repository root, `node scripts/check-consumer.mjs` tests a temporary local workspace. `node scripts/check-consumer.mjs --registry` creates an isolated consumer without a path override, downloads the public release and runs the same checks.
