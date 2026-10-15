///|
test "range accepts viable prefixes and clamps only when requested" {
  let day = @mooninput.range(1, 31, width=2).unwrap()
  assert_eq(@mooninput.Editor::new(day).unwrap().status(), @mooninput.Empty)
  assert_eq(
    @mooninput.Editor::new(day, initial="3").unwrap().status(),
    @mooninput.Incomplete,
  )
  assert_eq(day.format("31"), Ok("31"))
  assert_eq(day.format("00") is Err(_), true)
  assert_eq(day.format("4") is Err(_), true)
  assert_eq(day.format("1a") is Err(_), true)
  let fixed = @mooninput.range(1, 31, width=2, autofix=true).unwrap()
  assert_eq(fixed.format("4"), Ok("3"))
  assert_eq(fixed.format("39"), Ok("31"))
  assert_eq(fixed.format("00"), Ok("01"))
  assert_eq(@mooninput.range(-1, 2) is Err(_), true)
  assert_eq(@mooninput.range(100, 200, width=2) is Err(_), true)
}

///|
test "range exhaustive membership and invalid edits are atomic" {
  let mask = @mooninput.range(100, 249, width=3).unwrap()
  for n in 0..<1000 {
    let mut text = n.to_string()
    while text.length() < 3 {
      text = "0" + text
    }
    match @mooninput.Editor::new(mask, initial=text) {
      Ok(editor) => {
        assert_eq(n >= 100 && n <= 249, true)
        assert_eq(editor.status(), @mooninput.Complete)
      }
      Err(_) => assert_eq(n < 100 || n > 249, true)
    }
  }
  let editor = @mooninput.Editor::new(mask, initial="24").unwrap()
  assert_eq(editor.insert("9").unwrap().value(), Ok("249"))
  assert_eq(editor.insert("x") is Err(_), true)
  assert_eq(editor.raw(), "24")
}

///|
test "enumeration canonicalizes prefixes defensively and respects case policy" {
  let values = ["EUR", "USD", "USDT"]
  let mask = @mooninput.enumeration(values, case_sensitive=false).unwrap()
  values[0] = "BAD"
  assert_eq(mask.format("eu"), Ok("EU"))
  let editor = @mooninput.Editor::new(mask, initial="usd").unwrap()
  assert_eq(editor.status(), @mooninput.Complete)
  assert_eq(editor.value(), Ok("USD"))
  assert_eq(editor.insert("t").unwrap().value(), Ok("USDT"))
  assert_eq(mask.format("GBP") is Err(_), true)
  assert_eq(
    @mooninput.enumeration(["A", "a"], case_sensitive=false) is Err(_),
    true,
  )
  assert_eq(@mooninput.enumeration([]) is Err(_), true)
  assert_eq(
    @mooninput.enumeration(["Yes"]).unwrap().format("yes") is Err(_),
    true,
  )
}

///|
test "dynamic selection switches automatically and dispatches from full values" {
  let choices = [
    ("short", @mooninput.pattern("##-##").unwrap()),
    ("long", @mooninput.pattern("###-###").unwrap()),
  ]
  let mask = @mooninput.dynamic(choices).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234").unwrap()
  assert_eq(editor.active_mask(), Some("short"))
  assert_eq(editor.display(), "12-34")
  let editor = editor.insert("5").unwrap()
  assert_eq(editor.active_mask(), Some("long"))
  assert_eq(editor.display(), "123-45")
  let editor = editor.backspace().unwrap()
  assert_eq(editor.active_mask(), Some("short"))
  let dispatched = @mooninput.dynamic(choices, dispatch=fn(text) {
    if text.length() > 0 && text.to_array()[0] == '9' {
      Some("long")
    } else {
      None
    }
  }).unwrap()
  assert_eq(
    @mooninput.Editor::new(dispatched, initial="9123").unwrap().active_mask(),
    Some("long"),
  )
  let rerouted = @mooninput.Editor::new(dispatched, initial="1234")
    .unwrap()
    .select(0, 1)
    .unwrap()
    .insert("9")
    .unwrap()
  assert_eq(rerouted.active_mask(), Some("long"))
  assert_eq(rerouted.raw(), "9234")
  let rerouted = rerouted.select(0, 1).unwrap().insert("1").unwrap()
  assert_eq(rerouted.active_mask(), Some("short"))
  let bad = @mooninput.dynamic(choices, dispatch=fn(_) { Some("missing") }).unwrap()
  assert_eq(bad.format("12") is Err(_), true)
}

///|
test "custom masks and validators preserve editable invalid prefixes" {
  let even = @mooninput.custom(
    fn(text) {
      if text == "2" || text == "4" {
        @mooninput.Complete
      } else {
        @mooninput.Invalid("even digit required")
      }
    },
    max_length=1,
  ).unwrap()
  let invalid = @mooninput.Editor::new(even, initial="3").unwrap()
  assert_eq(invalid.status(), @mooninput.Invalid("even digit required"))
  assert_eq(invalid.value() is Err(_), true)
  assert_eq(invalid.set_value("4").unwrap().value(), Ok("4"))
  assert_eq(even.format("44") is Err(_), true)
  let lower = @mooninput.with_prepare(
    @mooninput.enumeration(["yes"]).unwrap(),
    fn(text) {
      String::from_array(text.to_array().map(fn(c) { c.to_ascii_lowercase() }))
    },
  )
  assert_eq(lower.format("YES"), Ok("yes"))
  let semantic = @mooninput.with_validation(@mooninput.pattern("##").unwrap(), fn(
    text,
  ) {
    if text == "13" {
      @mooninput.Invalid("reserved")
    } else {
      @mooninput.Complete
    }
  })
  assert_eq(
    @mooninput.Editor::new(semantic, initial="1").unwrap().status(),
    @mooninput.Incomplete,
  )
  assert_eq(
    @mooninput.Editor::new(semantic, initial="13").unwrap().status(),
    @mooninput.Invalid("reserved"),
  )
}

///|
test "named composites normalize raw and formatted data and expose fields" {
  let mask = @mooninput.composite([
    @mooninput.Block(
      "currency",
      @mooninput.enumeration(["USD", "EUR"]).unwrap(),
    ),
    @mooninput.Literal(" "),
    @mooninput.Block(
      "amount",
      @mooninput.decimal(precision=2, grouped=false).unwrap(),
    ),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="USD123.40").unwrap()
  assert_eq(editor.display(), "USD 123.40")
  assert_eq(editor.raw(), "USD123.40")
  assert_eq(editor.status(), @mooninput.Complete)
  assert_eq(editor.value(), Ok("USD 123.40"))
  assert_eq(editor.fields()[0].name, "currency")
  assert_eq(editor.fields()[0].value, "USD")
  assert_eq(editor.fields()[1].name, "amount")
  assert_eq(editor.fields()[1].value, "123.40")
  assert_eq(mask.format("EUR 45.00"), Ok("EUR 45.00"))
  assert_eq(
    @mooninput.Editor::new(mask, initial="EUR").unwrap().status(),
    @mooninput.Incomplete,
  )
  let selected = editor.select(4, 10).unwrap().insert("7").unwrap()
  assert_eq(selected.display(), "USD 7")
  assert_eq(selected.raw(), "USD7")
}

///|
test "composites prefer a complete partition over greedy incomplete splits" {
  let mask = @mooninput.composite([
    @mooninput.Block("head", @mooninput.enumeration(["1", "12"]).unwrap()),
    @mooninput.Block("tail", @mooninput.pattern("#").unwrap()),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="12").unwrap()
  assert_eq(editor.status(), @mooninput.Complete)
  assert_eq(editor.fields()[0].value, "1")
  assert_eq(editor.fields()[1].value, "2")
}

///|
test "optional composite fields and bounded repeats preserve partial status" {
  let mask = @mooninput.composite([
    @mooninput.Block("main", @mooninput.pattern("##").unwrap()),
    @mooninput.Literal("/"),
    @mooninput.Optional("extension", @mooninput.pattern("AA").unwrap()),
  ]).unwrap()
  assert_eq(mask.format("12"), Ok("12"))
  assert_eq(
    @mooninput.Editor::new(mask, initial="12").unwrap().status(),
    @mooninput.Complete,
  )
  assert_eq(
    @mooninput.Editor::new(mask, initial="12a").unwrap().status(),
    @mooninput.Incomplete,
  )
  assert_eq(mask.format("12ab"), Ok("12/AB"))
  assert_eq(mask.format("12/ab"), Ok("12/AB"))
  let full = @mooninput.Editor::new(mask, initial="12ab").unwrap()
  assert_eq(full.select(3, 5).unwrap().insert("").unwrap().display(), "12")
  let middle = full.select(3, 4).unwrap().insert("c").unwrap()
  assert_eq(middle.display(), "12/CB")
  assert_eq(middle.selection().start, 4)
  let repeated = @mooninput.repeat(@mooninput.pattern("##").unwrap(), 1, 3).unwrap()
  assert_eq(
    @mooninput.Editor::new(repeated, initial="1234").unwrap().status(),
    @mooninput.Complete,
  )
  assert_eq(
    @mooninput.Editor::new(repeated, initial="123").unwrap().status(),
    @mooninput.Incomplete,
  )
  assert_eq(repeated.format("1234567") is Err(_), true)
  assert_eq(
    @mooninput.repeat(@mooninput.pattern("#").unwrap(), 2, 1) is Err(_),
    true,
  )
}

///|
test "composite leading and trailing literals appear at meaningful boundaries" {
  let mask = @mooninput.composite([
    @mooninput.Literal("$ "),
    @mooninput.Block("amount", @mooninput.pattern("##").unwrap()),
    @mooninput.Literal(" "),
    @mooninput.Literal("USD"),
  ]).unwrap()
  assert_eq(mask.format(""), Ok(""))
  assert_eq(mask.format("1"), Ok("$ 1"))
  assert_eq(mask.format("12"), Ok("$ 12 USD"))
  assert_eq(mask.format("$ 12 USD"), Ok("$ 12 USD"))
  let editor = @mooninput.Editor::new(mask, initial="12").unwrap()
  assert_eq(editor.value(), Ok("$ 12 USD"))
  assert_eq(editor.backspace().unwrap().display(), "$ 1")
  assert_eq(@mooninput.composite([@mooninput.Literal("only")]) is Err(_), true)
}

///|
test "repeated nested composites retain suffix literals and named field paths" {
  let unit = @mooninput.composite([
    @mooninput.Block("quantity", @mooninput.pattern("##").unwrap()),
    @mooninput.Literal(" kg"),
  ]).unwrap()
  let mask = @mooninput.repeat(unit, 1, 2).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234").unwrap()
  assert_eq(editor.display(), "12 kg34 kg")
  assert_eq(editor.raw(), "1234")
  assert_eq(editor.value(), Ok("12 kg34 kg"))
  assert_eq(mask.format("12 kg34 kg"), Ok("12 kg34 kg"))
  assert_eq(editor.fields()[1].name, "0.quantity")
  assert_eq(editor.fields()[1].value, "12")
  assert_eq(editor.backspace().unwrap().display(), "12 kg3")
  let literal_selection = editor.select(2, 5).unwrap()
  assert_eq(literal_selection.insert("").unwrap().display(), "12 kg34 kg")
}

///|
test "composite names and public fields are defensive and unicode offsets work" {
  let mask = @mooninput.composite([
    @mooninput.Block("left", @mooninput.pattern("X").unwrap()),
    @mooninput.Literal("😀"),
    @mooninput.Block("right", @mooninput.pattern("#").unwrap()),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="你2").unwrap()
  assert_eq(editor.display(), "你😀2")
  assert_eq(editor.display_offset(1), Ok(1))
  assert_eq(editor.display_offset(2), Ok(4))
  assert_eq(editor.raw_index(3), Ok(1))
  let fields = editor.fields()
  fields[0] = { name: "bad", value: "bad", }
  assert_eq(editor.fields()[0].name, "left")
  assert_eq(
    @mooninput.composite([
      @mooninput.Block("same", @mooninput.pattern("#").unwrap()),
      @mooninput.Block("same", @mooninput.pattern("#").unwrap()),
    ])
    is Err(_),
    true,
  )
}
