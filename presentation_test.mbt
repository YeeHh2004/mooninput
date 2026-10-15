///|
test "presentation placeholders preserve pattern layout and editable indexes" {
  let mask = @mooninput.presentation(
    @mooninput.pattern("##-##").unwrap(),
    placeholder='_',
  ).unwrap()
  let empty = @mooninput.Editor::new(mask).unwrap()
  assert_eq(empty.display(), "__-__")
  assert_eq(empty.raw(), "")
  assert_eq(empty.status(), @mooninput.Empty)
  assert_eq(empty.raw_index(5), Ok(0))
  let one = empty.select(0, 0).unwrap().insert("1").unwrap()
  assert_eq(one.display(), "1_-__")
  assert_eq(one.selection(), { start: 1, end: 1, })
  assert_eq(one.raw_index(5), Ok(1))
  let two = one.select(3, 5).unwrap().insert("2").unwrap()
  assert_eq(two.display(), "12-__")
  assert_eq(two.raw(), "12")
  assert_eq(two.display_offset(2), Ok(2))
  assert_eq(two.select(2, 2).unwrap().insert("34").unwrap().value(), Ok("1234"))
}

///|
test "presentation concealment keeps literals and maps unequal Unicode widths" {
  let mask = @mooninput.presentation(
    @mooninput.pattern("X-X").unwrap(),
    placeholder='🟢',
    concealed='●',
  ).unwrap()
  let one = @mooninput.Editor::new(mask, initial="😀").unwrap()
  assert_eq(one.display(), "●-🟢")
  assert_eq(one.raw(), "😀")
  assert_eq(one.select(3, 3).unwrap().selection(), { start: 2, end: 2, })
  assert_eq(one.select(3, 4).unwrap().selection(), { start: 2, end: 4, })
  assert_eq(one.raw_index(4), Ok(1))
  let full = one.select(4, 4).unwrap().insert("你").unwrap()
  assert_eq(full.display(), "●-●")
  assert_eq(full.value(), Ok("😀你"))
  assert_eq(full.backspace().unwrap().raw(), "😀")
  let wide = @mooninput.presentation(
    @mooninput.pattern("##").unwrap(),
    concealed='😀',
  ).unwrap()
  let full = @mooninput.Editor::new(wide, initial="12").unwrap()
  assert_eq(full.display(), "😀😀")
  assert_eq(full.select(1, 1).unwrap().selection(), { start: 0, end: 0, })
  assert_eq(full.raw_index(2), Ok(1))
  assert_eq(full.select(1, 3).unwrap().backspace().unwrap().raw(), "")
}

///|
test "presentation date and eager generated literals retain validation" {
  let mask = @mooninput.presentation(@mooninput.iso_date(), placeholder='_').unwrap()
  assert_eq(@mooninput.Editor::new(mask).unwrap().display(), "____-__-__")
  let invalid = @mooninput.Editor::new(mask, initial="20230229").unwrap()
  assert_eq(invalid.display(), "2023-02-29")
  assert_eq(invalid.status(), @mooninput.Invalid("day is outside this month"))
  let eager = @mooninput.presentation(
    @mooninput.pattern("+##-##").unwrap(),
    eager=true,
  ).unwrap()
  assert_eq(@mooninput.Editor::new(eager).unwrap().display(), "+")
  let two = @mooninput.Editor::new(eager, initial="12").unwrap()
  assert_eq(two.display(), "+12-")
  assert_eq(two.raw(), "12")
  assert_eq(two.select(4, 4).unwrap().insert("3").unwrap().display(), "+12-3")
  assert_eq(
    @mooninput.presentation(@mooninput.decimal().unwrap(), eager=true) is Err(_),
    true,
  )
  assert_eq(
    @mooninput.presentation(@mooninput.iso_date(), placeholder='\n') is Err(_),
    true,
  )
}

///|
test "presentation wraps extension masks without changing canonical output" {
  let number = @mooninput.presentation(
    @mooninput.range(0, 99, width=2).unwrap(),
    placeholder='_',
    concealed='*',
  ).unwrap()
  let one = @mooninput.Editor::new(number, initial="4").unwrap()
  assert_eq(one.display(), "*_")
  let full = one.select(2, 2).unwrap().insert("2").unwrap()
  assert_eq(full.display(), "**")
  assert_eq(full.raw(), "42")
  assert_eq(full.value(), Ok("42"))
  let compound = @mooninput.composite([
    @mooninput.Block("prefix", @mooninput.pattern("AA").unwrap()),
    @mooninput.Literal(":"),
    @mooninput.Block("serial", @mooninput.range(0, 99, width=2).unwrap()),
  ]).unwrap()
  let hidden = @mooninput.presentation(compound, concealed='*').unwrap()
  let hidden = @mooninput.Editor::new(hidden, initial="ab42").unwrap()
  assert_eq(hidden.display(), "**:**")
  assert_eq(hidden.raw(), "AB42")
  assert_eq(hidden.value(), Ok("AB:42"))
  assert_eq(hidden.fields(), [
    { name: "prefix", value: "AB", },
    { name: "serial", value: "42", },
  ])
  let alternatives = @mooninput.dynamic([
    ("short", @mooninput.pattern("##").unwrap()),
    ("long", @mooninput.pattern("###").unwrap()),
  ]).unwrap()
  let presented = @mooninput.presentation(alternatives, concealed='*').unwrap()
  assert_eq(
    @mooninput.Editor::new(presented, initial="12").unwrap().active_mask(),
    Some("short"),
  )
  let huge = @mooninput.custom(_ => @mooninput.Complete, max_length=8192).unwrap()
  assert_eq(@mooninput.presentation(huge, placeholder='😀') is Err(_), true)
}

///|
test "value postprocessing affects only complete canonical results" {
  let mask = @mooninput.with_value(@mooninput.pattern("AA-##").unwrap(), value => {
    "ref:" + value
  })
  let partial = @mooninput.Editor::new(mask, initial="ab1").unwrap()
  assert_eq(partial.display(), "AB-1")
  assert_eq(partial.value(), Err(@mooninput.InvalidValue("incomplete")))
  let full = partial.insert("2").unwrap()
  assert_eq(full.display(), "AB-12")
  assert_eq(full.raw(), "AB12")
  assert_eq(full.value(), Ok("ref:AB12"))
  let over = @mooninput.with_value(@mooninput.pattern("#").unwrap(), _ => {
    String::make(8193, 'x')
  })
  assert_eq(@mooninput.Editor::new(over, initial="1") is Err(_), true)
}

///|
test "explicit commit revalidates transformations and preserves old snapshots" {
  let mask = @mooninput.decimal(precision=2).unwrap()
  let before = @mooninput.Editor::new(mask, initial="0012.5").unwrap()
  let after = before.commit(value => value + "0").unwrap()
  assert_eq(before.raw(), "0012.5")
  assert_eq(after.raw(), "12.50")
  assert_eq(after.display(), "12.50")
  assert_eq(after.value(), Ok("12.50"))
  assert_eq(before.commit(_ => "x") is Err(_), true)
  assert_eq(
    before.commit(_ => "12.").unwrap_err(),
    @mooninput.InvalidValue("incomplete"),
  )
  let partial = @mooninput.Editor::new(mask, initial="12.").unwrap()
  assert_eq(
    partial.commit(_ => "12").unwrap_err(),
    @mooninput.InvalidValue("incomplete"),
  )
  assert_eq(
    before.commit(_ => String::make(8193, '1')).unwrap_err(),
    @mooninput.TooLong(8192),
  )
}
