///|
test "phone formats raw and formatted input" {
  let mask = @mooninput.pattern("### ### ####").unwrap()
  assert_eq(mask.format("1234567890"), Ok("123 456 7890"))
  assert_eq(mask.format("123 456 7890"), Ok("123 456 7890"))
  assert_eq(mask.format("123"), Ok("123"))
  assert_eq(mask.format("1234"), Ok("123 4"))
  assert_eq(mask.format(""), Ok(""))
}

///|
test "uppercases codes and preserves optional extension" {
  let mask = @mooninput.pattern("AA-####[/**]").unwrap()
  assert_eq(mask.format("ab1234"), Ok("AB-1234"))
  assert_eq(mask.format("ab1234c5"), Ok("AB-1234/C5"))
  assert_eq(mask.format("ab-1234/c5"), Ok("AB-1234/C5"))
}

///|
test "escaped syntax and supplementary characters" {
  assert_eq(
    @mooninput.pattern("\\#XX").unwrap().format("你😀"),
    Ok("#你😀"),
  )
  assert_eq(
    @mooninput.pattern("XX").unwrap().format("e\u{301}"),
    Ok("e\u{301}"),
  )
}

///|
test "rejects invalid characters and overflow atomically" {
  assert_eq(
    @mooninput.pattern("##").unwrap().format("12x"),
    Err(@mooninput.TooLong(2)),
  )
  assert_eq(
    @mooninput.pattern("##").unwrap().format("x"),
    Err(@mooninput.InvalidCharacter(0, "x")),
  )
  assert_eq(
    @mooninput.pattern("X").unwrap().format("\n"),
    Err(@mooninput.InvalidCharacter(0, "\n")),
  )
}

///|
test "rejects malformed patterns" {
  for
    source in [
      "", "abc", "##-", "##[", "##]", "#[#]#", "#[[]]", "#[]", "#\\", "#\n#",
    ] {
    match @mooninput.pattern(source) {
      Err(_) => ()
      Ok(_) => fail("expected invalid pattern: " + source)
    }
  }
}
