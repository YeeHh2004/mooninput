///|
test "heterogeneous slots reject shifts that violate later constraints" {
  let code = @mooninput.Editor::new(
    @mooninput.pattern("AA-##").unwrap(),
    initial="AB12",
  ).unwrap()
  assert_eq(
    code.select(0, 0).unwrap().delete_forward().unwrap_err(),
    @mooninput.InvalidCharacter(1, "1"),
  )
  assert_eq(code.raw(), "AB12")
  assert_eq(code.select(0, 1).unwrap().insert("c").unwrap().display(), "CB-12")
}

///|
test "pattern literal-only input and optional all-slots" {
  let mask = @mooninput.pattern("+##").unwrap()
  assert_eq(mask.format("+"), Ok(""))
  assert_eq(mask.format("+1"), Ok("+1"))
  assert_eq(mask.format("-1"), Err(@mooninput.InvalidCharacter(0, "-")))
  assert_eq(@mooninput.pattern("[##]").unwrap().format("1"), Ok("1"))
  assert_eq(
    @mooninput.pattern("*A").unwrap().format("!a"),
    Err(@mooninput.InvalidCharacter(0, "!")),
  )
}

///|
test "decimal duplicate radix and misplaced signs" {
  assert_eq(
    @mooninput.decimal().unwrap().format("1.2.3"),
    Err(@mooninput.InvalidCharacter(3, ".")),
  )
  assert_eq(
    amount("12").select(1, 1).unwrap().insert("-").unwrap_err(),
    @mooninput.InvalidCharacter(1, "-"),
  )
  assert_eq(
    @mooninput.decimal(grouped=false).unwrap().format("1,234"),
    Err(@mooninput.InvalidCharacter(1, ",")),
  )
  assert_eq(amount("-000.00").value(), Ok("-0.00"))
}

///|
test "selection deletion and boundary no-ops" {
  assert_eq(
    phone("123456").select(2, 6).unwrap().delete_forward().unwrap().raw(),
    "126",
  )
  assert_eq(phone("123").delete_forward().unwrap().raw(), "123")
  assert_eq(
    phone("123").select(0, 0).unwrap().backspace().unwrap().raw(),
    "123",
  )
  assert_eq(phone("123").select(2, 3).unwrap().backspace().unwrap().raw(), "12")
  assert_eq(
    phone("123").select(0, 3).unwrap().insert("").unwrap().status(),
    @mooninput.Empty,
  )
}

///|
test "bounded reconciliation rejects huge transient input before allocating diff" {
  assert_eq(
    phone("").reconcile(String::make(8193, '1'), 0, 0).unwrap_err(),
    @mooninput.TooLong(8192),
  )
  assert_eq(
    amount("").reconcile(String::make(513, '1'), 0, 0).unwrap_err(),
    @mooninput.TooLong(512),
  )
}

///|
test "reconcile range mapping and failed native edit" {
  assert_eq(amount("1234").reconcile("1,234", 2, 4).unwrap().selection(), {
    start: 2,
    end: 4,
  })
  assert_eq(
    phone("123").reconcile("12x3", 3, 3).unwrap_err(),
    @mooninput.InvalidCharacter(2, "x"),
  )
  let editor = @mooninput.Editor::new(
    @mooninput.pattern("X##").unwrap(),
    initial="😀12",
  ).unwrap()
  assert_eq(editor.select(1, 2).unwrap().selection(), { start: 0, end: 2, })
}

///|
test "errors provide stable useful text" {
  assert_eq(@mooninput.InvalidPattern("x").message(), "Invalid pattern: x")
  assert_eq(
    @mooninput.InvalidCharacter(2, "x").message(),
    "Invalid character at slot 2: x",
  )
  assert_eq(@mooninput.TooLong(2).message(), "Input exceeds limit 2")
  assert_eq(
    @mooninput.InvalidSelection.message(),
    "Selection is outside the displayed value",
  )
  assert_eq(@mooninput.InvalidConfig("x").message(), "Invalid configuration: x")
  assert_eq(@mooninput.InvalidValue("empty").message(), "Value is empty")
}
