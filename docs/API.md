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

`insert(text)` replaces selected editable characters. `backspace()`/`delete_forward()` delete a selection or a neighboring editable scalar. `set_value(text)` replaces the entire field. `raw_index(displayOffset)` and `display_offset(rawScalarIndex)` expose the mapping.

`status()` returns Empty, Incomplete, Complete or Invalid(reason). `value()` returns a complete submission value or InvalidValue. A date value uses YYYY-MM-DD; a pattern value is unformatted; a decimal value is an exact string with redundant leading integer zeros removed. `display()` and `raw()` remain available for incomplete/invalid dates.

## Browser

Use built `web/mooninput.mjs` and source `web/adapter.mjs` together. `bindInput` accepts type=text/tel/search/password/url. Types number/date lack required selection behavior and are rejected. Use inputmode for a suitable software keyboard.

```js
const binding = bindInput(element, {kind:'pattern',pattern:'AA-####[/**]'}, {
  historyLimit: 100,
  onChange(state) { /* feed state.value into your form */ },
  onError({code,message}) { /* announce a rejected operation */ }
});
```

- `state`: detached frozen object: raw, display, start, end, status, reason, value.
- `setValue(string)`: programmatic update through the core; success contributes to history.
- `reset(string?)`: use supplied text or current `element.defaultValue`; a successful reset clears undo/redo. Invalid reset data preserves the previous value and history and calls onError.
- `undo()` / `redo()`: restore snapshot and selection; new changes clear redo.
- `destroy()`: remove listeners and discard history. Idempotent. Destroy before rebinding.
- `onChange` is the integration signal. Intercepted edits do not dispatch another synthetic native input event, avoiding recursion.
- A direct assignment to element.value is not an edit event. Use setValue. Native form reset is handled after its default action; canceled reset events are respected, including controls associated using the form attribute. Destroy removes this coordination. Applications own required-field policy and submission validation.
- Composition defers normalization until completion. No network calls or persistence occur.

`createEditor(config, initial)` works without DOM. `apply(op,text,start,end)` returns {ok,state} or {ok:false,code,error,state?}. Omitting both positions uses the current selection, so select followed by insert replaces that range. Supplying only start creates a collapsed caret. `restore(snapshot)` restores raw and selection. Config: kind pattern/decimal/date, pattern, precision, signed, grouped as applicable.

## JSON boundary

`YeeHh2004/mooninput/protocol` exports `process(String) -> String`; the JS bridge exports the same function. All request fields below are required:

```json
{"config":{"kind":"pattern","pattern":"##-##"},"value":"1234","op":"insert","start":3,"end":5,"text":"99"}
```

value is previous **raw** text. Operations: init, set, select, insert, backspace, delete, reconcile. init/set ignore start/end after schema decoding; reconcile uses positions in proposed text. Config defaults: precision 2, signed false, grouped true. Requests over 65,536 UTF-16 units and malformed types are rejected. No global handles or retained sessions exist.

Error codes: pattern, character, length, selection, config, value. Rejected edits preserve content; the returned state retains a valid submitted selection where possible. Configuration/schema errors can omit state. Additional object fields are ignored; unknown mask kinds/operations are rejected.
