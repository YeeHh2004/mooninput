///|
fn phone(value : String) -> @mooninput.Editor {
  @mooninput.Editor::new(
    @mooninput.pattern("### ### ####").unwrap(),
    initial=value,
  ).unwrap()
}

///|
test "insertion in middle and immutable previous snapshot" {
  let before = phone("123456")
  let after = before.select(2, 2).unwrap().insert("9").unwrap()
  assert_eq(before.display(), "123 456")
  assert_eq(after.display(), "129 345 6")
  assert_eq(after.selection(), { start: 3, end: 3, })
}

///|
test "selection replacement across formatting boundary" {
  let after = phone("1234567890").select(2, 6).unwrap().insert("99").unwrap()
  assert_eq(after.raw(), "129967890")
  assert_eq(after.display(), "129 967 890")
  assert_eq(after.selection(), { start: 5, end: 5, })
}

///|
test "backspace and delete skip literal separator" {
  assert_eq(
    phone("123456").select(4, 4).unwrap().backspace().unwrap().raw(),
    "12456",
  )
  assert_eq(
    phone("123456").select(3, 3).unwrap().delete_forward().unwrap().raw(),
    "12356",
  )
  assert_eq(
    phone("123456").select(3, 4).unwrap().backspace().unwrap().raw(),
    "123456",
  )
}

///|
test "selection bounds and immutable invalid edit" {
  let before = phone("123")
  assert_eq(before.select(-1, 0).unwrap_err(), @mooninput.InvalidSelection)
  assert_eq(before.select(2, 1).unwrap_err(), @mooninput.InvalidSelection)
  assert_eq(before.select(0, 4).unwrap_err(), @mooninput.InvalidSelection)
  assert_eq(
    before.insert("a").unwrap_err(),
    @mooninput.InvalidCharacter(3, "a"),
  )
  assert_eq(before.raw(), "123")
}

///|
test "unicode UTF16 selection expands a partial surrogate range" {
  let editor = @mooninput.Editor::new(
    @mooninput.pattern("XXX").unwrap(),
    initial="你😀a",
  ).unwrap()
  assert_eq(editor.display().length(), 4)
  assert_eq(editor.select(2, 2).unwrap().selection(), { start: 1, end: 1, })
  assert_eq(
    editor.select(2, 3).unwrap().insert("好").unwrap().raw(),
    "你好a",
  )
  assert_eq(
    editor.select(1, 1).unwrap().delete_forward().unwrap().raw(),
    "你a",
  )
  assert_eq(editor.select(3, 3).unwrap().backspace().unwrap().raw(), "你a")
}

///|
test "public scalar mapping roundtrips every raw boundary" {
  let editor = phone("1234567890")
  for i in 0..<=10 {
    assert_eq(editor.raw_index(editor.display_offset(i).unwrap()), Ok(i))
  }
  assert_eq(editor.raw_index(3), Ok(3))
  assert_eq(editor.raw_index(4), Ok(3))
}

///|
test "optional group completeness and empty status" {
  let base = @mooninput.Editor::new(@mooninput.pattern("##[-##]").unwrap()).unwrap()
  assert_eq(base.status(), @mooninput.Empty)
  assert_eq(base.insert("1").unwrap().status(), @mooninput.Incomplete)
  assert_eq(base.insert("12").unwrap().status(), @mooninput.Complete)
  assert_eq(base.insert("123").unwrap().status(), @mooninput.Incomplete)
  assert_eq(base.insert("1234").unwrap().value(), Ok("1234"))
}

///|
test "empty boundaries and complete paste" {
  let editor = phone("")
  assert_eq(editor.backspace().unwrap().raw(), "")
  assert_eq(editor.delete_forward().unwrap().raw(), "")
  assert_eq(editor.insert("123 456 7890").unwrap().value(), Ok("1234567890"))
  assert_eq(editor.value(), Err(@mooninput.InvalidValue("empty")))
}
