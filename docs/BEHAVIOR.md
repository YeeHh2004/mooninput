# Supported behavior and limits

## Patterns

#: ASCII digit. A: ASCII letter normalized to uppercase. *: ASCII letter/digit normalized to uppercase. X: printable Unicode scalar. Other printable characters are literals. Backslash escapes a token/bracket/backslash. One optional suffix [ ... ] is allowed; nesting and following content are rejected. At least one slot is required. Trailing literals are rejected because there is no subsequent content to trigger display.

AA-####[/**] accepts ab1234, displaying AB-1234, or ab1234c5, displaying AB-1234/C5. The required base may be Complete; if an optional suffix starts, it must be filled completely. Literals appear only before populated slots.

Literal-only selections remove no raw characters. A collapsed backspace/delete beside a separator removes the previous/next editable character. With heterogeneous slots, shifting content into an incompatible slot class is rejected; direct replacement of a selected slot works normally.

Raw input is tried first, then exact formatted paste. **Raw wins if both interpretations are valid**, such as a literal digit before a digit slot or a literal before X. Prefer separators excluded by the neighboring slot class (spaces/hyphens for digits) when accepting both forms. Do not assume arbitrary displays have a unique inverse; preserve the returned raw value. No optional branch alternatives or regex-mask execution are implemented.

Limits: pattern source 4,096 UTF-16 units; patterned input 8,192 UTF-16 units. Invalid/control characters and excess content reject the whole edit. Uppercase normalization for A/* is intentional.

## Decimals

Radix is '.', grouping separator ',' when enabled. No locale guessing: 1,234.50 is accepted; 1,23 and 1.234,50 are rejected as whole values. No currency metadata, arithmetic, tax, exponent notation or rounding is implemented.

Precision: 0..18 fractional digits. Signed is opt-in. '-', '.', '-.', '12.' remain editable but incomplete; '.5' submits '0.5'. Leading integer zeros remain visible and are removed from submitted values. Fractional zeros and negative zero signs are preserved. Values stay strings, even beyond JavaScript's safe integer range.

Raw content limit: 256 characters. Decimal input/display limit: 512 UTF-16 units. Applications choose business bounds.

## Dates

YYYY-MM-DD uses proleptic Gregorian rules, years 0001..9999, including century leap rules. No timezone, time of day, historical calendar transition or locale date parsing is implied. Completed invalid dates remain editable with Invalid(reason); value() errors. Incomplete dates are not prematurely calendar-validated.

## Selection and browser

Positions use UTF-16 on both JS and Wasm GC. X operates on Unicode scalars, **not grapheme clusters**. Combining marks and emoji sequences can consist of multiple editable scalars. Core selection handling does not split surrogate pairs. X is single-line printable input.

reconcile preserves raw content and selection when the proposed display is unchanged, including ambiguous literal masks. Otherwise it first normalizes a whole proposed display and maps its selection. If a native edit left generated separators in old positions, it reconstructs one contiguous edit from the previous display; the fallback caret follows inserted content. Arbitrary multi-edit browser transformations do not guarantee complex-selection preservation.

The adapter intercepts basic insert/paste, selected cut, backward/forward delete and undo/redo. Other native changes use reconciliation. Composition processing is deferred. CI runs Chromium, Firefox and WebKit with synthetic composition lifecycles; this does not establish compatibility with every physical mobile keyboard, OS input method, assistive technology or actual Safari/iOS device.

The adapter owns bounded field history and synchronizes native form reset with its current defaultValue, clearing history on success. Canceled resets are ignored. Invalid reset values restore the previous state and retain history. Controls remain associated through their current form property; destroy also cancels queued reset processing. Core snapshots are immutable and do not implement a history service. Cross-field rules, required-field policy, focus order and server validation remain application responsibilities.
