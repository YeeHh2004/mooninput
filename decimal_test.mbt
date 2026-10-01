///|
fn amount(value : String) -> @mooninput.Editor {
  @mooninput.Editor::new(
    @mooninput.decimal(signed=true).unwrap(),
    initial=value,
  ).unwrap()
}

///|
test "decimal grouping and exact large integers" {
  let editor = amount("9007199254740993.10")
  assert_eq(editor.display(), "9,007,199,254,740,993.10")
  assert_eq(editor.value(), Ok("9007199254740993.10"))
  assert_eq(amount("1,234.50").raw(), "1234.50")
}

///|
test "decimal intermediate states are preserved" {
  for text in ["-", ".", "-.", "12."] {
    let editor = amount(text)
    assert_eq(editor.raw(), text)
    assert_eq(editor.status(), @mooninput.Incomplete)
    assert_eq(editor.value(), Err(@mooninput.InvalidValue("incomplete")))
  }
  assert_eq(amount(".5").value(), Ok("0.5"))
  assert_eq(amount("-.5").value(), Ok("-0.5"))
  assert_eq(amount("00012.50").value(), Ok("12.50"))
}

///|
test "decimal invalid grouping and ambiguous locale paste" {
  let mask = @mooninput.decimal().unwrap()
  for
    text in [
      "1,23", "1,2,3", "1.234,50", "1e3", "NaN", "Infinity", " 12", "12 ",
    ] {
    match @mooninput.Editor::new(mask, initial=text) {
      Err(_) => ()
      Ok(_) => fail("must reject " + text)
    }
  }
}

///|
test "decimal precision rejects rather than truncates" {
  let before = amount("1.23")
  assert_eq(
    before.insert("4").unwrap_err(),
    @mooninput.InvalidValue("fraction exceeds configured precision"),
  )
  assert_eq(before.raw(), "1.23")
  assert_eq(
    @mooninput.decimal(precision=19).unwrap_err(),
    @mooninput.InvalidConfig("precision must be between 0 and 18"),
  )
  assert_eq(
    @mooninput.decimal(precision=-1).unwrap_err(),
    @mooninput.InvalidConfig("precision must be between 0 and 18"),
  )
}

///|
test "decimal edit moves caret across new grouping" {
  let after = amount("123").insert("4").unwrap()
  assert_eq(after.display(), "1,234")
  assert_eq(after.selection(), { start: 5, end: 5, })
  assert_eq(after.select(2, 2).unwrap().backspace().unwrap().raw(), "234")
  assert_eq(after.select(1, 1).unwrap().delete_forward().unwrap().raw(), "134")
}

///|
test "decimal selection replacement and sign constraints" {
  let before = amount("-1234.56")
  assert_eq(before.select(1, 6).unwrap().insert("8").unwrap().raw(), "-8.56")
  assert_eq(
    before.select(3, 3).unwrap().insert("-").unwrap_err(),
    @mooninput.InvalidCharacter(2, "-"),
  )
  assert_eq(
    @mooninput.decimal(signed=false).unwrap().format("-1"),
    Err(@mooninput.InvalidCharacter(0, "-")),
  )
  assert_eq(
    @mooninput.decimal(precision=0).unwrap().format("1."),
    Err(@mooninput.InvalidCharacter(1, ".")),
  )
  assert_eq(
    @mooninput.decimal(grouped=false).unwrap().format("1234.50"),
    Ok("1234.50"),
  )
}
