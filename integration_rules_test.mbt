///|
test "concealed native edits preserve existing raw content" {
  let mask = @mooninput.presentation(
    @mooninput.pattern("XXXXX").unwrap(),
    concealed='*',
  ).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="abcd").unwrap()
  assert_eq(editor.display(), "****")
  let reconciled = editor.reconcile("**z**", 3, 3).unwrap()
  assert_eq(reconciled.raw(), "abzcd")
  assert_eq(reconciled.display(), "*****")
}

///|
test "composite keeps semantic invalid date editable beside another block" {
  let mask = @mooninput.composite([
    @mooninput.Block("date", @mooninput.date().unwrap()),
    @mooninput.Literal(" "),
    @mooninput.Block("code", @mooninput.pattern("AA").unwrap()),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="20240229ab").unwrap()
  assert_eq(editor.status(), @mooninput.Complete)
  let changed = editor.select(3, 4).unwrap().insert("3").unwrap()
  assert_eq(changed.raw(), "20230229AB")
  assert_eq(changed.status(), @mooninput.Invalid("day is outside this month"))
  assert_eq(changed.value() is Err(_), true)
  assert_eq(
    changed.select(3, 4).unwrap().insert("4").unwrap().status(),
    @mooninput.Complete,
  )
}

///|
test "dynamic regex and localized number retain branch data through middle edits" {
  let mask = @mooninput.dynamic([
    ("sku", @mooninput.regex("[A-Z]{2}[0-9]{3}").unwrap()),
    ("amount", @mooninput.number(radix=',', group_separator=" ").unwrap()),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="AB123").unwrap()
  assert_eq(editor.active_mask(), Some("sku"))
  assert_eq(
    editor.select(2, 3).unwrap().insert("9").unwrap().value(),
    Ok("AB923"),
  )
  let editor = editor.set_value("12345,67").unwrap()
  assert_eq(editor.active_mask(), Some("amount"))
  assert_eq(editor.display(), "12 345,67")
  assert_eq(editor.value(), Ok("12345.67"))
  let editor = editor.select(3, 4).unwrap().insert("9").unwrap()
  assert_eq(editor.display(), "12 945,67")
  assert_eq(editor.value(), Ok("12945.67"))
}

///|
test "presentation wrapping dynamic repeat retains complete value and fields" {
  let mask = @mooninput.dynamic([
    (
      "digits",
      @mooninput.repeat(@mooninput.pattern("##").unwrap(), 1, 3).unwrap(),
    ),
    ("letters", @mooninput.regex("[A-Z]{2,6}").unwrap()),
  ]).unwrap()
  let mask = @mooninput.presentation(mask, concealed='•').unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234").unwrap()
  assert_eq(editor.active_mask(), Some("digits"))
  assert_eq(editor.value(), Ok("1234"))
  assert_eq(editor.display(), "••••")
  assert_eq(editor.fields()[0].name, "0")
  let editor = editor.select(0, 2).unwrap().insert("56").unwrap()
  assert_eq(editor.value(), Ok("5634"))
  let editor = editor.set_value("ABCDE").unwrap()
  assert_eq(editor.active_mask(), Some("letters"))
  assert_eq(editor.value(), Ok("ABCDE"))
}

///|
test "localized native edits recover grouping and preserve canonical values" {
  let mask = @mooninput.number(
    radix=',',
    group_separator=" ",
    pad_fraction=true,
  ).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234,5").unwrap()
  assert_eq(editor.display(), "1 234,5")
  assert_eq(editor.raw(), "1234,5")
  assert_eq(editor.value(), Ok("1234.50"))
  let changed = editor.reconcile("1 9234,5", 3, 3).unwrap()
  assert_eq(changed.raw(), "19234,5")
  assert_eq(changed.display(), "19 234,5")
  assert_eq(changed.value(), Ok("19234.50"))
}

///|
test "nested concealment and repeated concealed characters reconcile by caret" {
  let mask = @mooninput.composite([
    @mooninput.Block(
      "secret",
      @mooninput.presentation(
        @mooninput.pattern("XXXX[X]").unwrap(),
        concealed='*',
      ).unwrap(),
    ),
    @mooninput.Literal("-"),
    @mooninput.Block("code", @mooninput.pattern("##").unwrap()),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="abcd12").unwrap()
  assert_eq(editor.display(), "****-12")
  let changed = editor.reconcile("**z**-12", 3, 3).unwrap()
  assert_eq(changed.raw(), "abzcd12")
  assert_eq(changed.value(), Ok("abzcd-12"))
  let direct = @mooninput.presentation(
    @mooninput.pattern("XXXXX").unwrap(),
    concealed='*',
  ).unwrap()
  let editor = @mooninput.Editor::new(direct, initial="abcd").unwrap()
  assert_eq(editor.reconcile("*****", 3, 3).unwrap().raw(), "ab*cd")
  assert_eq(editor.reconcile("***", 2, 2).unwrap().raw(), "abd")
}

///|
test "placeholder native replacement does not enter generated text into raw" {
  let mask = @mooninput.presentation(
    @mooninput.pattern("XXXXXX").unwrap(),
    placeholder='_',
  ).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="ab").unwrap()
  assert_eq(editor.display(), "ab____")
  let changed = editor.reconcile("abz___", 3, 3).unwrap()
  assert_eq(changed.raw(), "abz")
  assert_eq(changed.display(), "abz___")
}

///|
test "native number edits keep canonical padding separate from editable input" {
  let mask = @mooninput.number(
    radix=',',
    group_separator=" ",
    pad_fraction=true,
  ).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234,5").unwrap()
  let changed = editor.reconcile("1 239,5", 5, 5).unwrap()
  assert_eq(changed.raw(), "1239,5")
  assert_eq(changed.value(), Ok("1239.50"))
}

///|
test "composite submission preserves canonical child transforms and number values" {
  let mask = @mooninput.composite([
    @mooninput.Block(
      "code",
      @mooninput.with_value(@mooninput.pattern("AA").unwrap(), fn(value) {
        "code:" + value
      }),
    ),
    @mooninput.Literal(" "),
    @mooninput.Block(
      "amount",
      @mooninput.number(radix=',', group_separator=" ", pad_fraction=true).unwrap(),
    ),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="AB1234,5").unwrap()
  assert_eq(editor.display(), "AB 1 234,5")
  assert_eq(editor.value(), Ok("code:AB 1234.50"))
  assert_eq(editor.fields()[0].value, "code:AB")
  assert_eq(editor.fields()[1].value, "1234.50")
}

///|
test "no op literal edits preserve an explicitly formatted ambiguous partition" {
  let mask = @mooninput.composite([
    @mooninput.Block("head", @mooninput.enumeration(["A", "AB"]).unwrap()),
    @mooninput.Literal(" "),
    @mooninput.Block("tail", @mooninput.regex("[A-Z]{1,2}").unwrap()),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="A BC").unwrap()
  assert_eq(editor.display(), "A BC")
  let changed = editor.select(1, 2).unwrap().insert("").unwrap()
  assert_eq(changed.display(), "A BC")
  assert_eq(changed.fields()[0].value, "A")
  assert_eq(changed.fields()[1].value, "BC")
}

///|
test "composite callback expansion is bounded after canonical composition" {
  let expanded = @mooninput.with_value(@mooninput.pattern("#").unwrap(), fn(_) {
    String::make(8192, 'a')
  })
  let mask = @mooninput.composite([
    @mooninput.Block("first", expanded),
    @mooninput.Block("second", expanded),
  ]).unwrap()
  assert_eq(
    @mooninput.Editor::new(mask, initial="12") is Err(@mooninput.TooLong(8192)),
    true,
  )
}
