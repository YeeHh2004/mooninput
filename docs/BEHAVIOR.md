# Supported behavior and limits

## Patterns

#: ASCII digit. A: ASCII letter normalized to uppercase. *: ASCII letter/digit normalized to uppercase. X: printable Unicode scalar. Other printable characters are literals. Backslash escapes a token/bracket/backslash. One optional suffix [ ... ] is allowed; nesting and following content are rejected. At least one slot is required. Trailing literals are rejected because there is no subsequent content to trigger display.

AA-####[/**] accepts ab1234, displaying AB-1234, or ab1234c5, displaying AB-1234/C5. The required base may be Complete; if an optional suffix starts, it must be filled completely. Literals appear only before populated slots.

Literal-only selections remove no raw characters. A collapsed backspace/delete beside a separator removes the previous/next editable character. With heterogeneous slots, shifting content into an incompatible slot class is rejected; direct replacement of a selected slot works normally.

Raw input is tried first, then exact formatted paste. **Raw wins if both interpretations are valid**, such as a literal digit before a digit slot or a literal before X. Prefer separators excluded by the neighboring slot class (spaces/hyphens for digits) when accepting both forms. Do not assume arbitrary displays have a unique inverse; preserve the returned raw value. Use dynamic/composite rules for alternatives and regex() for regular expressions. These are separate rule constructors, not extra pattern-string syntax.

Limits: pattern source 4,096 UTF-16 units; patterned input 8,192 UTF-16 units. Invalid/control characters and excess content reject the whole edit. Uppercase normalization for A/* is intentional.

## Legacy decimals and configurable numbers

Radix is '.', grouping separator ',' when enabled. No locale guessing: 1,234.50 is accepted; 1,23 and 1.234,50 are rejected as whole values. No currency metadata, arithmetic, tax, exponent notation or rounding is implemented.

Precision: 0..18 fractional digits. Signed is opt-in. '-', '.', '-.', '12.' remain editable but incomplete; '.5' submits '0.5'. Leading integer zeros remain visible and are removed from submitted values. Fractional zeros and negative zero signs are preserved. Values stay strings, even beyond JavaScript's safe integer range.

Raw content limit: 256 characters. Decimal input/display limit: 512 UTF-16 units. These defaults describe decimal(). number() additionally configures a single-scalar radix, optional single-scalar group separator, alternative radix mappings, exact string min/max and explicit autofix. Radix mappings must not collide with digits, sign or grouping. Raw text uses the configured radix, canonical values use '.'. Bound comparisons never convert to floating point. Outside values remain Invalid and editable unless autofix explicitly clamps them.

Formatted numeric fragments are normalized before insertion/overwrite for direct numbers and transparent validation/value/presentation wrappers. Bounds/autofix apply to the complete proposed value, so pasting a small fragment into a larger existing value does not clamp that fragment in isolation. with_prepare instead transforms the entire proposed input before parsing and deliberately does not forward this fragment hook; pattern overwrite keeps its existing slot-aware counting path. Canonical output remains subject to the numeric length limit after zero padding.

normalize_zeros trims canonical redundant zeros; pad_fraction pads complete canonical values. While editing, display/raw stay as typed so generated zeros cannot accidentally change an integer magnitude or block further typing. Explicit native commit can materialize canonical output using a caller-provided formatter; direct browser number bindings do this in commit/blur using the configured radix. Nested/composite rules do not automatically commit each child. No rounding is performed.

## Dates

YYYY-MM-DD uses proleptic Gregorian rules, years 0001..9999, including century leap rules. No timezone, time of day, historical calendar transition or locale date parsing is implied. Completed invalid dates remain editable with Invalid(reason); value() errors. Incomplete dates are not prematurely calendar-validated.

date() supports exactly one YYYY, MM and DD token each, in configurable order with printable literals, including trailing literals such as YYYY年MM月DD日. Bounds and canonical values use ISO dates. Use range blocks for time-of-day inputs.

Raw date digits are parsed before stripping a literal suffix. A numeric suffix, for example the final 0 in YYYYMMDD0, therefore does not consume a genuine final day digit during raw input or later edits. Full formatted text with that suffix is also accepted.

## Dynamic, composite and custom rules

Dynamic candidates are evaluated from the whole proposed input on every parse. Complete candidates win, then smaller capacity, then declaration order; a native dispatch callback can explicitly select a named branch. JSON startsWith uses longest matching prefix. None from native dispatch falls back to automatic selection; an unknown explicit name errors.

Composite preserves each child's raw/display/canonical values and named fields. Explicit literals are included in composite canonical submission text. Children may be nested, optional or finitely repeated, including trailing unit literals. Completed semantic Invalid states remain editable across block boundaries. Variable-width adjacent blocks can have ambiguous segmentation: complete partitions are preferred, with deterministic longest fitting candidates. Choose fixed widths, disjoint alphabets or explicit business normalization when exact segment identity matters. Even a visible separator does not make concatenated raw text uniquely invertible. No-op literal edits and replacements producing the same raw content preserve the existing partition; edits that change raw or raw-only reconstruction may select another valid partition. Editor::restore and the protocol's optional previous display preserve a saved partition only after both representations are strictly revalidated; a malformed snapshot is rejected.

Composite limits:64 parts,2048 total child capacities plus literals,2048 input/display UTF-16 units,8192 canonical units,16384 parsing steps per pass. Repeat is finite,0..32 copies with max>=min; it uses composite budgets. Dynamic supports1..64 distinctly named candidates. Enumeration supports1..64 nonempty values of at most128 UTF-16 units. Range is unsigned fixed width1..9, maximum999999999. Custom input is printable and bounded; its max_length counts UTF-16 units. Native callbacks must be deterministic, side-effect free, and preparation must be idempotent for raw snapshot reconstruction. Exceptions in user callbacks propagate.

If the composite search budget expires after a fully consumed, validated editable partition has been found, that result is retained. An incomplete search with no such partition remains an error; fallback never truncates unconsumed overflow.

The portable regex subset uses NFA state sets and prefix reachability; finite maximum lengths are inferred for composition. max_length counts Unicode scalars, independently of the8192 UTF-16 hard ceiling. A viable prefix must have a complete continuation satisfying both limits; unpaired UTF-16 surrogates are rejected. Mixed-limit continuation analysis is capped at262144 NFA visits and returns InvalidValue if exhausted. Syntax/state limits and unsupported ECMAScript features are detailed in [IMASK-COVERAGE](IMASK-COVERAGE.md). No host-side JS regular expression executes mask rules.

Presentation only changes display. Hidden raw values remain available to the application. Pattern/iso_date placeholders know future literal layout; generic masks append placeholders to declared capacity. Eager literals require a direct pattern/iso_date. A hidden display cannot encode every possible native replacement unambiguously; intercepted edits and contiguous native changes preserve raw content, while arbitrary unchanged hidden-text replacement has no recoverable information. This is display concealment, not encryption.

## Selection and browser

Positions use UTF-16 on both JS and Wasm GC. X operates on Unicode scalars, **not grapheme clusters**. Combining marks and emoji sequences can consist of multiple editable scalars. Core selection handling does not split surrogate pairs. X is single-line printable input.

reconcile preserves raw content and selection when the proposed display is unchanged, including ambiguous literal masks. Presentation wrappers reconstruct contiguous changes before parsing so hidden characters/placeholders never replace underlying raw data. Otherwise it first normalizes a whole proposed display and maps its selection. If a native edit left generated separators in old positions, it reconstructs one contiguous edit from the previous display; the fallback caret follows inserted content. Arbitrary multi-edit browser transformations do not guarantee complex-selection preservation.

The adapter intercepts basic insert/paste, selected cut, backward/forward delete and undo/redo. Other native changes use reconciliation. Composition processing is deferred. CI runs Chromium, Firefox and WebKit with synthetic composition lifecycles; this does not establish compatibility with every physical mobile keyboard, OS input method, assistive technology or actual Safari/iOS device.

The adapter owns bounded field history and synchronizes native form reset with its current defaultValue, clearing history on success. Canceled resets are ignored. Invalid reset values restore the previous state and retain history; the snapshot includes the selection captured when the native reset event began, before the browser reset its value and selection. Controls remain associated through their current form property; destroy also cancels queued reset processing. Core snapshots are immutable and do not implement a history service. Cross-field rules, required-field policy, focus order and server validation remain application responsibilities.

History compares semantic state as well as raw text, including display-only partition changes. Saved states are revalidated before moving undo/redo entries. Rule updates are atomic; a change involving numeric/date rules anywhere in the old or new rule tree is rejected if it would change the current complete canonical value. This guards against silently reinterpreting a date order or decimal radix; clear or explicitly convert such values before changing formats.
