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
