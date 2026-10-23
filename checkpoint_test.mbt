///|
fn checkpoint_roundtrip(
  mask : @mooninput.Mask,
  editor : @mooninput.Editor,
) -> @mooninput.Editor raise {
  let selection = editor.selection()
  let restored = @mooninput.Editor::restore(
    mask,
    editor.raw(),
    editor.display(),
    selection.start,
    selection.end,
    replay=editor.replay_text(),
  ).unwrap()
  assert_eq(restored.raw(), editor.raw())
  assert_eq(restored.display(), editor.display())
  assert_eq(restored.status(), editor.status())
  assert_eq(restored.value(), editor.value())
  assert_eq(restored.selection(), selection)
  assert_eq(restored.fields(), editor.fields())
  assert_eq(restored.active_mask(), editor.active_mask())
  assert_eq(restored.replay_text(), editor.replay_text())
  restored
}

///|
fn checkpoint_variable_mask() -> @mooninput.Mask {
  let number = @mooninput.number(precision=0, group_separator="").unwrap()
  @mooninput.composite([
    @mooninput.Block("left", number),
    @mooninput.Literal("/"),
    @mooninput.Block("right", number),
  ]).unwrap()
}

///|
test "checkpoint replay retains hidden variable composite boundaries" {
  let base = checkpoint_variable_mask()
  let mask = @mooninput.presentation(base, concealed='●').unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1/23")
    .unwrap()
    .select(0, 1)
    .unwrap()
  assert_eq(editor.raw(), "123")
  assert_eq(editor.display(), "●/●●")
  assert_eq(editor.fields()[0].value, "1")
  assert_eq(editor.fields()[1].value, "23")
  assert_eq(editor.replay_text(), "1/23")
  assert_true(
    @mooninput.Editor::restore(mask, editor.raw(), editor.display(), 0, 1)
    is Err(_),
  )
  let restored = checkpoint_roundtrip(mask, editor)
  let same_rule = restored.with_mask(mask).unwrap()
  assert_eq(same_rule.fields(), editor.fields())
  assert_eq(same_rule.replay_text(), "1/23")
  assert_eq(same_rule.selection(), editor.selection())
  let selected = editor.select(2, 4).unwrap()
  let same_raw = selected.insert("23").unwrap()
  assert_eq(same_raw.fields(), editor.fields())
  assert_eq(same_raw.replay_text(), "1/23")
  checkpoint_roundtrip(mask, same_raw) |> ignore
  let unchanged = editor.reconcile(editor.display(), 2, 4).unwrap()
  assert_eq(unchanged.replay_text(), "1/23")
  checkpoint_roundtrip(mask, unchanged) |> ignore
}

///|
test "checkpoint prepared locale and invalid states replay their original input" {
  let base = @mooninput.number(
    radix=',',
    group_separator=".",
    min="1000",
    max="2000",
  ).unwrap()
  let mask = @mooninput.with_prepare(base, text => "1" + text)
  let complete = @mooninput.Editor::new(mask, initial="234,50").unwrap()
  assert_eq(complete.display(), "1.234,50")
  assert_eq(complete.value(), Ok("1234.50"))
  assert_eq(complete.replay_text(), "234,50")
  checkpoint_roundtrip(mask, complete) |> ignore
  assert_eq(complete.with_mask(mask).unwrap().value(), Ok("1234.50"))
  let invalid = @mooninput.Editor::new(mask, initial="9999,50").unwrap()
  assert_true(invalid.status() is @mooninput.Invalid(_))
  assert_eq(invalid.replay_text(), "9999,50")
  checkpoint_roundtrip(mask, invalid) |> ignore
  assert_true(
    invalid.with_mask(mask).unwrap().status() is @mooninput.Invalid(_),
  )
}

///|
test "checkpoint custom preparation captures edit inputs before transformation" {
  let mask = @mooninput.custom(_ => @mooninput.Invalid("pending review"), prepare=text => {
    text + "x"
  }).unwrap()
  let initial = @mooninput.Editor::new(mask, initial="ab").unwrap()
  assert_eq(initial.raw(), "abx")
  assert_eq(initial.replay_text(), "ab")
  checkpoint_roundtrip(mask, initial) |> ignore
  let edited = initial.insert("c").unwrap()
  assert_eq(edited.raw(), "abxcx")
  assert_eq(edited.replay_text(), "abxc")
  checkpoint_roundtrip(mask, edited) |> ignore
  let no_op = initial.select(0, 3).unwrap().insert("abx").unwrap()
  assert_eq(no_op.replay_text(), "ab")
  checkpoint_roundtrip(mask, no_op) |> ignore
}

///|
test "checkpoint captures the actual parse input for normalized pattern edits" {
  let next_digit = @mooninput.definition('Q', c => c.is_ascii_digit(), normalize=c => {
    ((c.to_int() - 48 + 1) % 10 + 48).unsafe_to_char()
  })
  let mask = @mooninput.pattern("QQ", definitions=[next_digit]).unwrap()
  let initial = @mooninput.Editor::new(mask, initial="12").unwrap()
  assert_eq(initial.raw(), "23")
  assert_eq(initial.replay_text(), "12")
  checkpoint_roundtrip(mask, initial) |> ignore
  let edited = initial.select(0, 1).unwrap().insert("3").unwrap()
  assert_eq(edited.raw(), "54")
  assert_eq(edited.replay_text(), "43")
  checkpoint_roundtrip(mask, edited) |> ignore
}

///|
test "checkpoint corrupt or oversized replay never falls back to raw or display" {
  let mask = @mooninput.pattern("##-##").unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234").unwrap()
  assert_true(
    @mooninput.Editor::restore(mask, "1234", "12-34", 0, 0, replay="9999")
    is Err(_),
  )
  assert_true(
    @mooninput.Editor::restore(mask, "1234", "12-34", 0, 0, replay="oops")
    is Err(_),
  )
  assert_true(
    @mooninput.Editor::restore(
      mask,
      "1234",
      "12-35",
      0,
      0,
      replay=editor.replay_text(),
    )
    is Err(_),
  )
  assert_true(
    @mooninput.Editor::restore(
      mask,
      "1235",
      "12-34",
      0,
      0,
      replay=editor.replay_text(),
    )
    is Err(_),
  )
  assert_eq(
    @mooninput.Editor::restore(
      mask,
      "1234",
      "12-34",
      0,
      0,
      replay=String::make(8193, '1'),
    ).unwrap_err(),
    @mooninput.TooLong(8192),
  )
  assert_eq(
    @mooninput.Editor::restore(mask, "1234", "12-34", 4, 2, replay="1234").unwrap_err(),
    @mooninput.InvalidSelection,
  )
}

///|
test "checkpoint legacy restore and rule changes retain compatible behavior" {
  let mask = checkpoint_variable_mask()
  let legacy = @mooninput.Editor::restore(mask, "123", "1/23", 2, 4).unwrap()
  assert_eq(legacy.fields()[0].value, "1")
  assert_eq(legacy.fields()[1].value, "23")
  assert_eq(legacy.replay_text(), "1/23")
  let editor = @mooninput.Editor::new(
      @mooninput.pattern("##-##").unwrap(),
      initial="1234",
    )
    .unwrap()
    .select(1, 4)
    .unwrap()
  let changed = editor.with_mask(@mooninput.pattern("####").unwrap()).unwrap()
  assert_eq(changed.display(), "1234")
  assert_eq(changed.selection(), { start: 1, end: 3, })
  assert_eq(changed.replay_text(), "1234")
}

///|
test "checkpoint real edits reconciliation set and dynamic branches remain reproducible" {
  let mask = @mooninput.dynamic([
    ("short", @mooninput.pattern("##-##").unwrap()),
    ("long", @mooninput.pattern("###-###").unwrap()),
  ]).unwrap()
  let initial = @mooninput.Editor::new(mask, initial="12-34").unwrap()
  checkpoint_roundtrip(mask, initial) |> ignore
  let inserted = initial.insert("5").unwrap()
  assert_eq(inserted.active_mask(), Some("long"))
  assert_eq(inserted.replay_text(), "12345")
  checkpoint_roundtrip(mask, inserted) |> ignore
  let deleted = inserted.backspace().unwrap()
  assert_eq(deleted.active_mask(), Some("short"))
  checkpoint_roundtrip(mask, deleted) |> ignore
  let number = @mooninput.number().unwrap()
  let amount = @mooninput.Editor::new(number, initial="1234.50").unwrap()
  let native = amount.reconcile("19,234.50", 2, 2).unwrap()
  checkpoint_roundtrip(number, native) |> ignore
  let set = native.set_value("9,876.00").unwrap()
  assert_eq(set.replay_text(), "9,876.00")
  checkpoint_roundtrip(number, set) |> ignore
}
