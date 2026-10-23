///|
test "composite rejects block names that collide with nested path syntax" {
  let digit = @mooninput.pattern("#").unwrap()
  let nested = @mooninput.composite([@mooninput.Block("x", digit)]).unwrap()
  assert_eq(
    @mooninput.composite([
      @mooninput.Block("a.x", digit),
      @mooninput.Block("a", nested),
    ])
    is Err(@mooninput.InvalidConfig(_)),
    true,
  )
  // Reserve the path delimiter at construction, before any input can populate
  // the conflicting paths. Unambiguous native names remain usable.
  assert_eq(
    @mooninput.composite([@mooninput.Block("a.x", digit)])
    is Err(@mooninput.InvalidConfig(_)),
    true,
  )
  let mask = @mooninput.composite([
    @mooninput.Block("group-a", digit),
    @mooninput.Block("group_2", nested),
    @mooninput.Block("组3", digit),
  ]).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="123").unwrap()
  let expected : Array[@mooninput.FieldValue] = [
    { name: "group-a", value: "1", },
    { name: "group_2", value: "2", },
    { name: "group_2.x", value: "2", },
    { name: "组3", value: "3", },
  ]
  assert_eq(editor.fields(), expected)
}

///|
test "optional prefix is not triggered by an unrelated unit suffix" {
  let mask = @mooninput.composite([
    @mooninput.Block("weight", @mooninput.pattern("##").unwrap()),
    @mooninput.Literal("/"),
    @mooninput.Optional("grade", @mooninput.pattern("AA").unwrap()),
    @mooninput.Literal(" kg"),
  ]).unwrap()
  let base = @mooninput.Editor::new(mask, initial="12").unwrap()
  assert_eq(base.display(), "12 kg")
  assert_eq(base.value(), Ok("12 kg"))
  assert_eq(base.raw(), "12")
  assert_eq(base.fields().length(), 1)
  assert_eq(mask.format("12 kg"), Ok("12 kg"))
  let partial = base.insert("a").unwrap()
  assert_eq(partial.display(), "12/A")
  assert_eq(partial.status(), @mooninput.Incomplete)
  assert_eq(partial.value() is Err(_), true)
  let full = partial.insert("b").unwrap()
  assert_eq(full.display(), "12/AB kg")
  assert_eq(full.value(), Ok("12/AB kg"))
  assert_eq(mask.format("12/AB kg"), Ok("12/AB kg"))
  let removed = full.select(3, 5).unwrap().insert("").unwrap()
  assert_eq(removed.display(), "12 kg")
  assert_eq(removed.fields().length(), 1)
  assert_eq(full.display(), "12/AB kg")
  assert_eq(mask.format("12/? kg") is Err(_), true)
  assert_eq(mask.format("12/AB kx") is Err(_), true)
}

///|
test "optional prefix uses the nearest block rather than later required input" {
  let mask = @mooninput.composite([
    @mooninput.Block("main", @mooninput.pattern("##").unwrap()),
    @mooninput.Literal("/"),
    @mooninput.Optional("grade", @mooninput.pattern("AA").unwrap()),
    @mooninput.Literal("-"),
    @mooninput.Block("code", @mooninput.pattern("AA").unwrap()),
    @mooninput.Literal(" units"),
  ]).unwrap()
  let base = @mooninput.Editor::new(mask, initial="12CD").unwrap()
  assert_eq(base.display(), "12-CD units")
  assert_eq(base.value(), Ok("12-CD units"))
  assert_eq(base.fields()[1].name, "code")
  assert_eq(base.fields()[1].value, "CD")
  assert_eq(mask.format("12-CD units"), Ok("12-CD units"))
  assert_eq(mask.format("12ABCD"), Ok("12/AB-CD units"))
  assert_eq(mask.format("12/AB-CD units"), Ok("12/AB-CD units"))
  assert_eq(
    @mooninput.Editor::new(mask, initial="12ABC").unwrap().status(),
    @mooninput.Incomplete,
  )
}

///|
test "optional placeholders retain layout without changing canonical literals" {
  let grade = @mooninput.pattern("AA").unwrap()
  let shown = @mooninput.presentation(grade, placeholder='_').unwrap()
  let mask = @mooninput.composite([
    @mooninput.Block("weight", @mooninput.pattern("##").unwrap()),
    @mooninput.Literal("/"),
    @mooninput.Optional("grade", shown),
    @mooninput.Literal(" kg"),
  ]).unwrap()
  let base = @mooninput.Editor::new(mask, initial="12").unwrap()
  assert_eq(base.display(), "12/__ kg")
  assert_eq(base.value(), Ok("12 kg"))
  assert_eq(base.status(), @mooninput.Complete)
  assert_eq(base.fields().length(), 1)
  let partial = @mooninput.Editor::new(mask, initial="12A").unwrap()
  assert_eq(partial.display(), "12/A_")
  assert_eq(partial.status(), @mooninput.Incomplete)
  let full = @mooninput.Editor::new(mask, initial="12AB").unwrap()
  assert_eq(full.display(), "12/AB kg")
  assert_eq(full.value(), Ok("12/AB kg"))
}

///|
test "optional omission preserves leading and consecutive trailing literals" {
  let mask = @mooninput.composite([
    @mooninput.Literal("["),
    @mooninput.Block("weight", @mooninput.pattern("##").unwrap()),
    @mooninput.Literal("/"),
    @mooninput.Optional("grade", @mooninput.pattern("AA").unwrap()),
    @mooninput.Literal("]"),
    @mooninput.Literal(" kg"),
  ]).unwrap()
  assert_eq(mask.format(""), Ok(""))
  assert_eq(mask.format("1"), Ok("[1"))
  assert_eq(mask.format("12"), Ok("[12] kg"))
  assert_eq(mask.format("[12] kg"), Ok("[12] kg"))
  assert_eq(mask.format("12AB"), Ok("[12/AB] kg"))
  assert_eq(mask.format("[12/AB] kg"), Ok("[12/AB] kg"))
  let editor = @mooninput.Editor::new(mask, initial="12").unwrap()
  assert_eq(editor.raw_index(4), Ok(2))
  assert_eq(editor.display_offset(2), Ok(3))
}

///|
test "long literal chains retain strict parsing and a shared search budget" {
  let digit = @mooninput.pattern("#").unwrap()
  let parts = [@mooninput.Block("main", digit)]
  for _ in 0..<18 {
    parts.push(@mooninput.Literal("a"))
  }
  let suffix = String::make(18, 'a')
  let literal_mask = @mooninput.composite(parts).unwrap()
  assert_eq(literal_mask.format("1"), Ok("1" + suffix))
  assert_eq(literal_mask.format("1" + suffix), Ok("1" + suffix))
  assert_eq(
    literal_mask.format("1" + suffix + "!") is Err(@mooninput.InvalidValue(_)),
    true,
  )
  // A real optional child makes prefix omission meaningful. A hostile suffix
  // can then require many alternatives, but all literal walks share the budget
  // and terminate with the documented typed error, without dropping input.
  parts.push(@mooninput.Optional("tail", digit))
  let alternatives = @mooninput.composite(parts).unwrap()
  assert_eq(
    alternatives.format("1" + suffix + "!"),
    Err(
      @mooninput.InvalidValue(
        "composite parsing exceeded its bounded search budget",
      ),
    ),
  )
  let empty_parts = [@mooninput.Block("main", digit)]
  for _ in 0..<18 {
    empty_parts.push(@mooninput.Literal(""))
  }
  assert_eq(
    @mooninput.composite(empty_parts) is Err(@mooninput.InvalidConfig(_)),
    true,
  )
}
