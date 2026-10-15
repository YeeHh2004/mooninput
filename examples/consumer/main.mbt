///|
fn main {
  let editor = @input.Editor::new(
    @input.pattern("AA-####").unwrap(),
    initial="ab1234",
  ).unwrap()
  println(editor.display())
  println(editor.value().unwrap())
}

///|
test "independent form consumer handles editing and submission" {
  let code = @input.Editor::new(
    @input.pattern("AA-####").unwrap(),
    initial="ab1234",
  ).unwrap()
  assert_eq(
    code.select(3, 7).unwrap().insert("0042").unwrap().display(),
    "AB-0042",
  )
  assert_eq(code.value(), Ok("AB1234"))
  let date = @input.Editor::new(@input.iso_date(), initial="20261002").unwrap()
  assert_eq(date.value(), Ok("2026-10-02"))
}

///|
test "independent consumer rejects precision loss and bad config" {
  assert_eq(
    @input.decimal(precision=19).unwrap_err(),
    @input.InvalidConfig("precision must be between 0 and 18"),
  )
  let amount = @input.Editor::new(@input.decimal().unwrap(), initial="0.10").unwrap()
  assert_eq(
    amount.insert("9").unwrap_err(),
    @input.InvalidValue("fraction exceeds configured precision"),
  )
  assert_eq(amount.value(), Ok("0.10"))
}

///|
test "independent consumer composes and dispatches public rules" {
  let combined = @input.composite([
    @input.Block("letters", @input.regex("[A-Z]{2}").unwrap()),
    @input.Literal("/"),
    @input.Block("digits", @input.range(0, 99, width=2).unwrap()),
  ]).unwrap()
  let edited = @input.Editor::new(combined, initial="AB42").unwrap()
  assert_eq(edited.display(), "AB/42")
  assert_eq(edited.value(), Ok("AB/42"))
  assert_eq(edited.fields()[0].value, "AB")
  let choice = @input.dynamic([
    ("code", combined),
    ("word", @input.enumeration(["ON", "OFF"]).unwrap()),
  ]).unwrap()
  assert_eq(
    @input.Editor::new(choice, initial="OFF").unwrap().active_mask(),
    Some("word"),
  )
  let custom = @input.with_validation(@input.pattern("####").unwrap(), value => {
    if value.length() < 4 {
      @input.Incomplete
    } else if value.has_prefix("12") {
      @input.Complete
    } else {
      @input.Invalid("prefix")
    }
  })
  assert_eq(@input.pipe(custom, "1234", unmask=true), Ok("1234"))
}
