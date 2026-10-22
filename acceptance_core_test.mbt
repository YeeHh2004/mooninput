///|
test "acceptance repeated invalid blocks remain editable within resource bounds" {
  let child = @mooninput.custom(
    _ => @mooninput.Invalid("review required"),
    max_length=8,
  ).unwrap()
  let mask = @mooninput.repeat(child, 8, 8).unwrap()
  let editor = match
    @mooninput.Editor::new(mask, initial=String::make(64, '1')) {
    Ok(editor) => editor
    Err(error) =>
      fail(
        "syntactically valid repeated input must stay editable: " +
        error.message(),
      )
  }
  assert_eq(editor.raw(), String::make(64, '1'))
  assert_eq(editor.status(), @mooninput.Invalid("review required"))
  assert_eq(editor.value() is Err(_), true)
  assert_eq(editor.fields().length(), 8)
  for field in editor.fields() {
    assert_eq(field.value, String::make(8, '1'))
  }
  let changed = editor.backspace().unwrap()
  assert_eq(changed.raw(), String::make(63, '1'))
  assert_eq(changed.status(), @mooninput.Invalid("review required"))
  assert_eq(editor.raw(), String::make(64, '1'))
  // A budget fallback may only retain a partition that consumed every input
  // character; an impossible overflow must never be silently truncated.
  assert_eq(
    @mooninput.Editor::new(mask, initial=String::make(65, '1')) is Err(_),
    true,
  )
}

///|
test "acceptance caller mutation does not modify range repeat composite snapshots" {
  let choices = ["USD", "EUR"]
  let parts = [
    @mooninput.Block("currency", @mooninput.enumeration(choices).unwrap()),
    @mooninput.Literal(" "),
    @mooninput.Block("day", @mooninput.range(1, 31, width=2).unwrap()),
  ]
  let mask = @mooninput.composite(parts).unwrap()
  let before = @mooninput.Editor::new(mask, initial="USD31").unwrap()
  choices[0] = "BAD"
  parts[1] = @mooninput.Literal("!")
  let fields = before.fields()
  fields[0] = { name: "wrong", value: "wrong", }
  let after = before.select(4, 6).unwrap().insert("02").unwrap()
  assert_eq(before.display(), "USD 31")
  assert_eq(before.fields()[0].value, "USD")
  assert_eq(after.display(), "USD 02")
  assert_eq(before.select(4, 6).unwrap().insert("99") is Err(_), true)
  assert_eq(before.display(), "USD 31")
}

///|
test "acceptance snapshot restore retains explicit composite partitions" {
  let mask = @mooninput.composite([
    @mooninput.Block("head", @mooninput.enumeration(["A", "AB"]).unwrap()),
    @mooninput.Literal(" "),
    @mooninput.Block("tail", @mooninput.regex("[A-Z]{1,2}").unwrap()),
  ]).unwrap()
  let original = @mooninput.Editor::new(mask, initial="A BC").unwrap()
  assert_eq(original.raw(), "ABC")
  assert_eq(
    @mooninput.Editor::new(mask, initial=original.raw()).unwrap().display(),
    "AB C",
  )
  let restored = @mooninput.Editor::restore(
    mask,
    original.raw(),
    original.display(),
    2,
    4,
  ).unwrap()
  assert_eq(restored.display(), "A BC")
  assert_eq(restored.value(), Ok("A BC"))
  assert_eq(restored.fields()[0].value, "A")
  assert_eq(restored.fields()[1].value, "BC")
  assert_eq(restored.selection().start, 2)
  assert_eq(restored.selection().end, 4)
  let unchanged = restored.insert("BC").unwrap()
  assert_eq(unchanged.display(), "A BC")
  assert_eq(unchanged.fields()[0].value, "A")
  assert_eq(unchanged.selection().start, 4)
  let changed = restored.insert("DE").unwrap()
  assert_eq(changed.display(), "A DE")
  let undone = @mooninput.Editor::restore(
    mask,
    original.raw(),
    original.display(),
    2,
    4,
  ).unwrap()
  assert_eq(undone.fields()[1].value, "BC")
}

///|
test "acceptance snapshot raw replay takes precedence over ambiguous display text" {
  let mask = @mooninput.pattern("1X[XX]").unwrap()
  let original = @mooninput.Editor::new(mask, initial="12").unwrap()
  assert_eq(original.display(), "112")
  assert_eq(
    @mooninput.Editor::new(mask, initial=original.display()).unwrap().raw(),
    "112",
  )
  let restored = @mooninput.Editor::restore(mask, "12", "112", 3, 3).unwrap()
  assert_eq(restored.raw(), "12")
  assert_eq(restored.display(), "112")
  assert_eq(restored.status(), @mooninput.Incomplete)
}

///|
test "acceptance snapshot restores concealed values and empty placeholders" {
  let mask = @mooninput.presentation(
    @mooninput.pattern("XX[XXX]").unwrap(),
    concealed='*',
  ).unwrap()
  let restored = @mooninput.Editor::restore(mask, "ab", "**", 0, 2).unwrap()
  assert_eq(restored.value(), Ok("ab"))
  assert_eq(restored.raw(), "ab")
  assert_eq(restored.display(), "**")
  assert_eq(@mooninput.Editor::restore(mask, "ab", "***", 0, 0) is Err(_), true)
  let placeholders = @mooninput.presentation(
    @mooninput.pattern("##-##").unwrap(),
    placeholder='_',
  ).unwrap()
  let restored = @mooninput.Editor::restore(placeholders, "", "__-__", 3, 3).unwrap()
  assert_eq(restored.status(), @mooninput.Empty)
  assert_eq(restored.raw(), "")
  assert_eq(restored.selection().start, 3)
}

///|
test "acceptance snapshot validates localized raw display and selection bounds" {
  let mask = @mooninput.number(
    radix=',',
    group_separator=" ",
    pad_fraction=true,
  ).unwrap()
  let restored = @mooninput.Editor::restore(mask, "1234,5", "1 234,5", 3, 5).unwrap()
  assert_eq(restored.value(), Ok("1234.50"))
  assert_eq(restored.raw(), "1234,5")
  assert_eq(restored.selection().end, 5)
  assert_eq(
    @mooninput.Editor::restore(mask, "1234,5", "1.234,5", 0, 0) is Err(_),
    true,
  )
  assert_eq(
    @mooninput.Editor::restore(mask, "9999,5", "1 234,5", 0, 0) is Err(_),
    true,
  )
  assert_eq(
    @mooninput.Editor::restore(mask, "1234,5", "1 234,5", -1, 0)
    is Err(@mooninput.InvalidSelection),
    true,
  )
  assert_eq(
    @mooninput.Editor::restore(mask, "1234,5", "1 234,5", 0, 99)
    is Err(@mooninput.InvalidSelection),
    true,
  )
  let range = @mooninput.range(1, 31, width=2, autofix=true).unwrap()
  assert_eq(@mooninput.Editor::restore(range, "99", "31", 0, 0) is Err(_), true)
  assert_eq(
    @mooninput.Editor::restore(range, "31", "31", 2, 2).unwrap().value(),
    Ok("31"),
  )
}
