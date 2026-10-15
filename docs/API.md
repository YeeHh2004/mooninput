# API and integration

The authoritative signatures are in [`pkg.generated.mbti`](../pkg.generated.mbti). Editing operations return `Result[Editor, InputError]`. Editors and masks expose no mutable arrays; old snapshots remain usable after successful or rejected edits.

## MoonBit

```moonbit
let specification = @input.decimal(precision=2, signed=true).unwrap()
let original = @input.Editor::new(specification, initial="1234.50").unwrap()
let edited = original.select(2, 3).unwrap().insert("9").unwrap()
println(edited.display()) // 1,934.50
println(edited.raw())     // 1934.50
println(edited.value().unwrap()) // 1934.50
```

`select(start, end)` uses ordered, inclusive-start/exclusive-end UTF-16 positions into **display**, not raw. Out-of-range and reversed selections return `InvalidSelection`. A collapsed position inside a surrogate pair snaps backward; a nonempty selection expands to whole Unicode scalars.

`insert(text, overwrite=false, skip_invalid=false)` replaces selected editable characters. Overwrite replaces the parsed number of editable scalars, excluding pasted separators; skip_invalid explicitly applies accepted characters one at a time. Default edits remain atomic. `backspace()`/`delete_forward()` delete a selection or a neighboring editable scalar. `set_value(text)` replaces the entire field. `raw_index(displayOffset)` and `display_offset(rawScalarIndex)` expose the mapping.

`status()` returns Empty, Incomplete, Complete or Invalid(reason). `value()` returns a complete submission value or InvalidValue. A date value uses YYYY-MM-DD; a pattern value is unformatted; a decimal value is an exact string with redundant leading integer zeros removed. `display()` and `raw()` remain available for incomplete/invalid dates.

## Composable rules (0.2)

| Constructor | Configuration / behavior |
| --- | --- |
| `definition(token, accept, normalize=...)` + `pattern(source, definitions=...)` | Native single-character callbacks. Normalized characters must remain accepted by the definition; preparation should be deterministic and idempotent. |
| `range(min,max,width=...,autofix=false)` | Nonnegative fixed-width integers and viable prefixes; autofix clamps impossible prefixes. |
| `enumeration(values,case_sensitive=true)` | Finite strings, editable prefixes, optional ASCII case folding. |
| `regex(source,case_insensitive=false,max_length=8192)` | Bounded portable NFA regular subset with viable-prefix editing; max_length counts Unicode scalars, plus global UTF-16 limit. |
| `dynamic([(name,mask),...],dispatch=...)` | Full-input selection on each edit; active_mask() identifies the selected branch. |
| `composite([Block(name,mask),Literal(text),Optional(name,mask),...])` | Named nested blocks, interior optionals, leading/trailing literals. fields() returns canonical block values; nested names use dotted paths. |
| `repeat(mask,min,max)` | Finite repetition of any bounded child rule. |
| `custom(validate,max_length=256,prepare=...)` | Native callback returns an input Status; Invalid stays editable but cannot submit. |
| `with_validation / with_prepare / with_value` | Add semantic validation, whole-input normalization or canonical complete-value postprocessing. |
| `number(...)` | Precision, signed input, explicit radix/group separator and mappings, exact string min/max, zero normalization, canonical padding, optional autofix. |
| `date(format=...,min=...,max=...)` | One YYYY/MM/DD field each in configured order with printable literals; bounds and canonical output use ISO dates. |
| `presentation(mask,placeholder=...,concealed=...,eager=false)` | Display-only presentation while preserving raw, canonical and field values. |

`Editor::with_mask(mask)` revalidates old raw text under another rule and maps selection by raw scalar boundaries. `Editor::commit(transform)` passes a complete canonical value into a native callback, then reparses and validates its result atomically. The callback must return text accepted by that mask's input format (localize a decimal radix or date ordering when needed). `pipe(mask,text,unmask=false)` produces display text; unmask=true requires and returns a complete canonical value.

Composite canonical values join child canonical values and explicit literal separators. They are not necessarily display text or raw text. Keep `raw` for editing, `value` for submission and `fields` for individual blocks. See [runnable rules](../examples/rules) and [complete limits](BEHAVIOR.md).

## Browser

Use built `web/mooninput.mjs` and source `web/adapter.mjs` together. `bindInput` accepts type=text/tel/search/password/url. Types number/date lack required selection behavior and are rejected. Use inputmode for a suitable software keyboard.

```js
const binding = bindInput(element, {kind:'pattern',pattern:'AA-####[/**]'}, {
  historyLimit: 100,
  onChange(state) { /* feed state.value into your form */ },
  onError({code,message}) { /* announce a rejected operation */ }
});
```

- `state`: detached frozen object: raw, display, start, end, status, reason, value, active and fields. Named field objects and their array are also detached and frozen.
- `setValue(string)`: programmatic update through the core; success contributes to history.
- `reset(string?)`: use supplied text or current `element.defaultValue`; a successful reset clears undo/redo. Invalid reset data preserves the previous value and history and calls onError.
- `undo()` / `redo()`: restore snapshot and selection; new changes clear redo.
- `updateOptions(patch)`: merge declarative configuration and revalidate existing raw atomically; success clears history and places the caret at the end. Number/date format changes that reinterpret a complete canonical value are rejected: clear or explicitly convert before changing the format.
- `commit()`: require complete valid input, finalize configured text transformation and render the result. Direct number configurations materialize canonical fractional padding using the configured radix; blur calls commit automatically for complete input.
- `destroy()`: remove listeners and discard history. Idempotent. Destroy before rebinding.
- `onChange` is the integration signal. Intercepted edits do not dispatch another synthetic native input event, avoiding recursion.
- `onAccept(state)` fires when an existing state changes raw/display/canonical text; `onComplete(state)` fires when a change produces a new complete value. Initial binding uses onChange only.
- A direct assignment to element.value is not an edit event. Use setValue. Native form reset is handled after its default action; canceled reset events are respected, including controls associated using the form attribute. Destroy removes this coordination. Applications own required-field policy and submission validation.
- Composition defers normalization until completion. No network calls or persistence occur.

`createEditor(config, initial)` works without DOM. `apply(op,text,start,end)` returns {ok,state} or {ok:false,code,error,state?}. Omitting both positions uses the current selection, so select followed by insert replaces that range. Supplying only start creates a collapsed caret. `restore(snapshot)` restores raw and selection. updateOptions is also available without DOM. Callback functions belong to the native MoonBit API; JSON configuration remains data.

## JSON boundary

`YeeHh2004/mooninput/protocol` exports `process(String) -> String`; the JS bridge exports the same function. All request fields below are required:

```json
{"config":{"kind":"pattern","pattern":"##-##"},"value":"1234","op":"insert","start":3,"end":5,"text":"99"}
```

value is previous **raw** text. Operations: init, set, select, insert, backspace, delete, reconcile, commit. init/set ignore start/end after schema decoding; reconcile uses positions in proposed text. Legacy decimal defaults: precision2, signed false, grouped true; number defaults signed true. Requests over 65,536 UTF-16 units, JSON nesting over48, rule nesting over16 and malformed types are rejected before or during rule construction. No global handles or retained sessions exist.

Declarative `kind` values and option keys:

| kind | Options |
| --- | --- |
| pattern | pattern, definitions:[{token,characters,uppercase}] |
| decimal | precision,signed,grouped (legacy) |
| number | precision,signed,radix,groupSeparator,mapRadix,min,max,padFraction,normalizeZeros,autofix |
| date | format,min,max |
| regex | source,caseInsensitive,maxLength (scalar count) |
| range | from,to,width,autofix |
| enum | values,caseSensitive |
| dynamic | masks:[child config with name and optional startsWith] |
| composite | parts:[{kind:"literal",literal} or {kind:"block"/"optional",name,rule}] |
| repeat | rule,minRepeat,maxRepeat |
| validate | rule,allowed,startsWith,equals,minLength,maxLength (UTF-16 lengths) |
| presentation | rule,placeholder,concealed,eager |

All top-level configs may set prepare: uppercase/lowercase/trim, commit: identity/uppercase/lowercase/trim, overwrite and skipInvalid. Unsupported prepare/commit modes are configuration errors. Dynamic startsWith dispatch uses the longest fitting configured prefix; absence of a prefix match falls back to normal candidate selection. Runnable configs are in [examples](../examples) and [the workbench](../web/advanced.mjs).

Error codes: pattern, character, length, selection, config, value. Rejected edits preserve content; the returned state retains a valid submitted selection where possible. Configuration/schema errors can omit state. Additional object fields are ignored; unknown mask kinds/operations are rejected.
