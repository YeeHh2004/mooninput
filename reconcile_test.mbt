///|
test "reconcile raw autofill preserves caret with generated literals" {
  let editor = phone("").reconcile("123456", 4, 4).unwrap()
  assert_eq(editor.display(), "123 456")
  assert_eq(editor.selection(), { start: 5, end: 5, })
}

///|
test "unchanged display preserves ambiguous raw value and selection" {
  let original = @mooninput.Editor::new(
    @mooninput.pattern("1####").unwrap(),
    initial="23",
  ).unwrap()
  let next = original.reconcile(original.display(), 1, 3).unwrap()
  assert_eq(next.raw(), "23")
  assert_eq(next.display(), "123")
  assert_eq(next.selection(), { start: 1, end: 3, })
  assert_eq(next.reconcile(next.display(), 3, 3).unwrap().raw(), "23")
  assert_eq(
    original.reconcile(original.display(), 0, 4).unwrap_err(),
    @mooninput.InvalidSelection,
  )
}

///|
test "unchanged display caret stays after separator and snaps unicode" {
  let original = phone("123456")
  assert_eq(original.reconcile(original.display(), 4, 4).unwrap().selection(), {
    start: 4,
    end: 4,
  })
  let unicode = @mooninput.Editor::new(
    @mooninput.pattern("XXX").unwrap(),
    initial="你😀a",
  ).unwrap()
  assert_eq(unicode.reconcile(unicode.display(), 2, 3).unwrap().selection(), {
    start: 1,
    end: 3,
  })
}

///|
test "reconcile transient native grouping via single edit" {
  let editor = amount("1234").reconcile("1,5234", 3, 3).unwrap()
  assert_eq(editor.display(), "15,234")
  assert_eq(editor.selection(), { start: 2, end: 2, })
  let p = phone("123456").reconcile("1723 456", 2, 2).unwrap()
  assert_eq(p.raw(), "1723456")
  assert_eq(p.selection(), { start: 2, end: 2, })
}

///|
test "reconcile preserves Unicode range and atomic rejection" {
  let initial = @mooninput.Editor::new(@mooninput.pattern("XXX").unwrap()).unwrap()
  let editor = initial.reconcile("你😀a", 2, 3).unwrap()
  assert_eq(editor.selection(), { start: 1, end: 3, })
  assert_eq(
    phone("123").reconcile("12x3", 3, 3).unwrap_err(),
    @mooninput.InvalidCharacter(2, "x"),
  )
  assert_eq(
    phone("123").reconcile("123", 4, 4).unwrap_err(),
    @mooninput.InvalidSelection,
  )
}

///|
test "bounded pattern and input size" {
  assert_eq(
    @mooninput.pattern(String::make(4097, '#')).unwrap_err(),
    @mooninput.TooLong(4096),
  )
  let mask = @mooninput.pattern("#").unwrap()
  assert_eq(mask.format(String::make(8193, '1')), Err(@mooninput.TooLong(8192)))
  assert_eq(
    @mooninput.decimal().unwrap().format(String::make(257, '1')),
    Err(@mooninput.TooLong(256)),
  )
  assert_eq(
    @mooninput.decimal().unwrap().format(String::make(513, '1')),
    Err(@mooninput.TooLong(512)),
  )
}

///|
test "unicode literal boundaries and public mapping errors" {
  let editor = @mooninput.Editor::new(
    @mooninput.pattern("😀##").unwrap(),
    initial="12",
  ).unwrap()
  assert_eq(editor.display(), "😀12")
  assert_eq(editor.select(1, 1).unwrap().selection(), { start: 0, end: 0, })
  assert_eq(editor.select(1, 2).unwrap().selection(), { start: 0, end: 2, })
  assert_eq(editor.raw_index(-1), Err(@mooninput.InvalidSelection))
  assert_eq(editor.raw_index(5), Err(@mooninput.InvalidSelection))
  assert_eq(editor.display_offset(3), Err(@mooninput.InvalidSelection))
}
