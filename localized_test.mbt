///|
test "localized number maps radix validates grouping and exposes exact canonical text" {
  let mask = @mooninput.number(radix=',', group_separator=" ", map_radix=".").unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234567.50").unwrap()
  assert_eq(editor.display(), "1 234 567,50")
  assert_eq(editor.raw(), "1234567,50")
  assert_eq(editor.value(), Ok("1234567.50"))
  assert_eq(mask.format("1 234 567,50"), Ok("1 234 567,50"))
  assert_eq(mask.format("1 234 567.50"), Ok("1 234 567,50"))
  assert_true(mask.format("12 34,50") is Err(_))
  assert_true(mask.format("1 234,5 0") is Err(_))
  assert_true(mask.format("1.2.3") is Err(_))
  assert_true(mask.format("1,234.5") is Err(_))
  let plain = @mooninput.number(group_separator="", precision=0, signed=false).unwrap()
  assert_eq(plain.format("000123"), Ok("000123"))
  assert_true(plain.format("1,234") is Err(_))
  assert_true(plain.format("-1") is Err(_))
}

///|
test "localized exact bounds distinguish adjacent values beyond binary floating point" {
  let mask = @mooninput.number(
    precision=3,
    min="9007199254740992.001",
    max="9007199254740992.003",
  ).unwrap()
  for
    text in [
      "9007199254740992.001", "9007199254740992.002", "9007199254740992.003",
    ] {
    assert_eq(
      @mooninput.Editor::new(mask, initial=text).unwrap().value(),
      Ok(text),
    )
  }
  for
    text in ["9007199254740992.000", "9007199254740992.004", "9007199254740993"] {
    let editor = @mooninput.Editor::new(mask, initial=text).unwrap()
    assert_true(editor.status() is @mooninput.Invalid(_))
    assert_true(editor.value() is Err(_))
  }
  let negative = @mooninput.number(min="-100.02", max="-100.01").unwrap()
  assert_eq(
    @mooninput.Editor::new(negative, initial="-100.02").unwrap().value(),
    Ok("-100.02"),
  )
  assert_true(
    @mooninput.Editor::new(negative, initial="-100.03").unwrap().status()
    is @mooninput.Invalid(_),
  )
  assert_true(
    @mooninput.Editor::new(negative, initial="-100.00").unwrap().status()
    is @mooninput.Invalid(_),
  )
  let zero = @mooninput.number(min="0", max="0").unwrap()
  assert_eq(
    @mooninput.Editor::new(zero, initial="-0.00").unwrap().value(),
    Ok("-0.00"),
  )
  assert_true(@mooninput.number(min="0.01", max="-0.01") is Err(_))
}

///|
test "localized decimal bounds and clamping match an exhaustive integer cents oracle" {
  fn cents_text(cents : Int) -> String {
    let amount = if cents < 0 { -cents } else { cents }
    let mut fraction = (amount % 100).to_string()
    if fraction.length() == 1 {
      fraction = "0" + fraction
    }
    (if cents < 0 { "-" } else { "" }) +
    (amount / 100).to_string() +
    "." +
    fraction
  }
  let strict = @mooninput.number(min="-1.23", max="0.45").unwrap()
  let fixed = @mooninput.number(min="-1.23", max="0.45", autofix=true).unwrap()
  for cents in -200..<=200 {
    let text = cents_text(cents)
    let editor = @mooninput.Editor::new(strict, initial=text).unwrap()
    if cents >= -123 && cents <= 45 {
      assert_eq(editor.value(), Ok(text))
    } else {
      assert_true(editor.status() is @mooninput.Invalid(_))
    }
    let expected = cents_text(cents.max(-123).min(45))
    assert_eq(
      @mooninput.Editor::new(fixed, initial=text).unwrap().value(),
      Ok(expected),
    )
  }
}

///|
test "localized bounds keep intermediate text editable and autofix is opt in" {
  let mask = @mooninput.number(min="100", max="999", precision=0).unwrap()
  let prefix = @mooninput.Editor::new(mask, initial="1").unwrap()
  assert_true(prefix.status() is @mooninput.Invalid(_))
  assert_eq(prefix.insert("00").unwrap().value(), Ok("100"))
  let fixed = @mooninput.number(min="100.01", max="200.02", autofix=true).unwrap()
  assert_eq(
    @mooninput.Editor::new(fixed, initial="1").unwrap().value(),
    Ok("100.01"),
  )
  assert_eq(
    @mooninput.Editor::new(fixed, initial="999").unwrap().value(),
    Ok("200.02"),
  )
  let negative = @mooninput.number(min="-2.50", max="-1.25", autofix=true).unwrap()
  assert_eq(
    @mooninput.Editor::new(negative, initial="-4").unwrap().value(),
    Ok("-2.50"),
  )
  assert_eq(
    @mooninput.Editor::new(negative, initial="0").unwrap().value(),
    Ok("-1.25"),
  )
  assert_eq(
    @mooninput.Editor::new(negative, initial="-").unwrap().status(),
    @mooninput.Incomplete,
  )
}

///|
test "localized fraction padding and zero normalization preserve exact values" {
  let normalized = @mooninput.number(precision=4, normalize_zeros=true).unwrap()
  assert_eq(
    @mooninput.Editor::new(normalized, initial="00012.3400").unwrap().value(),
    Ok("12.34"),
  )
  assert_eq(
    @mooninput.Editor::new(normalized, initial="-000.0000").unwrap().value(),
    Ok("-0"),
  )
  let padded = @mooninput.number(
    precision=3,
    radix=',',
    group_separator=" ",
    pad_fraction=true,
  ).unwrap()
  let editor = @mooninput.Editor::new(padded, initial="1234,5").unwrap()
  assert_eq(editor.display(), "1 234,5")
  assert_eq(editor.value(), Ok("1234.500"))
  let committed = editor
    .commit(fn(value) {
      String::from_array(
        value.to_array().map(fn(c) { if c == '.' { ',' } else { c } }),
      )
    })
    .unwrap()
  assert_eq(committed.display(), "1 234,500")
  assert_eq(committed.raw(), "1234,500")
  assert_eq(
    @mooninput.Editor::new(padded, initial="1234").unwrap().value(),
    Ok("1234.000"),
  )
  let incomplete = @mooninput.Editor::new(padded, initial="1234,").unwrap()
  assert_eq(incomplete.status(), @mooninput.Incomplete)
  assert_eq(incomplete.display(), "1 234,")
  let both = @mooninput.number(
    precision=2,
    normalize_zeros=true,
    pad_fraction=true,
  ).unwrap()
  assert_eq(
    @mooninput.Editor::new(both, initial="00012.30").unwrap().value(),
    Ok("12.30"),
  )
}

///|
test "localized explicit commit materializes fraction padding as editable digits" {
  let mask = @mooninput.number(precision=2, pad_fraction=true).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="12").unwrap()
  assert_eq(editor.display(), "12")
  assert_eq(editor.value(), Ok("12.00"))
  let committed = editor.commit(fn(value) { value }).unwrap()
  assert_eq(committed.display(), "12.00")
  let changed = committed.select(3, 4).unwrap().insert("5").unwrap()
  assert_eq(changed.value(), Ok("12.50"))
  assert_eq(changed.display(), "12.50")
  assert_eq(changed.selection(), { start: 4, end: 4, })
}

///|
test "localized grouped edits and native stale separator reconciliation preserve caret" {
  let mask = @mooninput.number(radix=',', group_separator=".").unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234,56").unwrap()
  assert_eq(editor.display(), "1.234,56")
  let edited = editor.select(2, 3).unwrap().insert("9").unwrap()
  assert_eq(edited.display(), "1.934,56")
  assert_eq(edited.value(), Ok("1934.56"))
  assert_eq(edited.selection(), { start: 3, end: 3, })
  let pasted = editor.select(0, 8).unwrap().insert("9.876,54").unwrap()
  assert_eq(pasted.raw(), "9876,54")
  assert_eq(pasted.value(), Ok("9876.54"))
  let native = editor.reconcile("19.234,56", 2, 2).unwrap()
  assert_eq(native.display(), "19.234,56")
  assert_eq(native.value(), Ok("19234.56"))
  assert_eq(native.selection(), { start: 2, end: 2, })
  let stale = editor.reconcile("1.934,56", 3, 3).unwrap()
  assert_eq(stale.value(), Ok("1934.56"))
}

///|
test "localized supplementary grouping uses UTF16 display positions" {
  let mask = @mooninput.number(group_separator="😀", precision=0).unwrap()
  let editor = @mooninput.Editor::new(mask, initial="1234").unwrap()
  assert_eq(editor.display(), "1😀234")
  assert_eq(editor.raw_index(2), Ok(1))
  assert_eq(editor.display_offset(2), Ok(4))
  assert_eq(editor.select(2, 3).unwrap().selection(), { start: 1, end: 3, })
  assert_eq(
    editor.select(3, 4).unwrap().insert("9").unwrap().value(),
    Ok("1934"),
  )
}

///|
test "localized dates support reordered fields Gregorian boundaries and canonical ISO output" {
  let mask = @mooninput.date(
    format="DD/MM/YYYY",
    min="2024-02-28",
    max="2024-03-01",
  ).unwrap()
  assert_eq(mask.format("29022024"), Ok("29/02/2024"))
  let editor = @mooninput.Editor::new(mask, initial="29/02/2024").unwrap()
  assert_eq(editor.value(), Ok("2024-02-29"))
  assert_eq(editor.fields()[0], { name: "year", value: "2024", })
  assert_eq(editor.fields()[1], { name: "month", value: "02", })
  assert_eq(editor.fields()[2], { name: "day", value: "29", })
  assert_eq(
    editor.select(0, 2).unwrap().insert("28").unwrap().value(),
    Ok("2024-02-28"),
  )
  assert_true(
    @mooninput.Editor::new(mask, initial="27/02/2024").unwrap().status()
    is @mooninput.Invalid(_),
  )
  assert_true(
    @mooninput.Editor::new(mask, initial="02/03/2024").unwrap().status()
    is @mooninput.Invalid(_),
  )
  let us = @mooninput.date(format="MM.DD.YYYY").unwrap()
  assert_eq(
    @mooninput.Editor::new(us, initial="02.29.2000").unwrap().value(),
    Ok("2000-02-29"),
  )
  assert_true(
    @mooninput.Editor::new(us, initial="02.29.1900").unwrap().status()
    is @mooninput.Invalid(_),
  )
  assert_eq(
    @mooninput.Editor::new(us, initial="022").unwrap().status(),
    @mooninput.Incomplete,
  )
  assert_true(@mooninput.date(format="DD/MM/YY") is Err(_))
  assert_true(@mooninput.date(format="YYYY-MM-MM") is Err(_))
  assert_true(@mooninput.date(min="2024-02-30") is Err(_))
  assert_true(@mooninput.date(min="2025-01-01", max="2024-12-31") is Err(_))
  let chinese = @mooninput.date(format="YYYY年MM月DD日").unwrap()
  assert_eq(chinese.format("20240229"), Ok("2024年02月29日"))
  assert_eq(
    @mooninput.pipe(chinese, "2024年02月29日", unmask=true),
    Ok("2024-02-29"),
  )
}

///|
test "localized custom definitions normalize slots reject duplicates and isolate configuration" {
  let hex = @mooninput.definition(
    'H',
    fn(c) {
      c.is_ascii_digit() ||
      (c.to_ascii_lowercase() >= 'a' && c.to_ascii_lowercase() <= 'f')
    },
    normalize=fn(c) { c.to_ascii_uppercase() },
  )
  let definitions = [hex]
  let mask = @mooninput.pattern("HH:HH", definitions~).unwrap()
  definitions[0] = @mooninput.definition('Z', fn(_) { true })
  assert_eq(mask.format("ab12"), Ok("AB:12"))
  assert_true(mask.format("gh12") is Err(_))
  let editor = @mooninput.Editor::new(mask, initial="ab12").unwrap()
  assert_eq(
    editor.select(0, 1).unwrap().insert("f").unwrap().value(),
    Ok("FB12"),
  )
  assert_true(@mooninput.pattern("HH", definitions=[hex, hex]) is Err(_))
  assert_true(
    @mooninput.pattern("#", definitions=[
      @mooninput.definition('[', fn(_) { true }),
    ])
    is Err(_),
  )
}

///|
test "localized overwrite and skip invalid edits retain the intended tail" {
  let editor = @mooninput.Editor::new(
    @mooninput.pattern("##-##-##").unwrap(),
    initial="123456",
  ).unwrap()
  assert_eq(
    editor.select(0, 0).unwrap().insert("98", overwrite=true).unwrap().display(),
    "98-34-56",
  )
  assert_eq(
    editor
    .select(0, 0)
    .unwrap()
    .insert("9x8", overwrite=true, skip_invalid=true)
    .unwrap()
    .display(),
    "98-34-56",
  )
  assert_eq(
    editor
    .select(0, 0)
    .unwrap()
    .insert("98-76", overwrite=true)
    .unwrap()
    .display(),
    "98-76-56",
  )
  let empty = @mooninput.Editor::new(@mooninput.pattern("##-##").unwrap()).unwrap()
  assert_eq(
    empty.insert("1a2-3b4", skip_invalid=true).unwrap().display(),
    "12-34",
  )
}

///|
test "localized with mask preserves selection validates raw and pipe distinguishes display from value" {
  let first = @mooninput.Editor::new(
      @mooninput.pattern("##-##").unwrap(),
      initial="1234",
    )
    .unwrap()
    .select(1, 4)
    .unwrap()
  let changed = first.with_mask(@mooninput.pattern("####").unwrap()).unwrap()
  assert_eq(changed.display(), "1234")
  assert_eq(changed.selection(), { start: 1, end: 3, })
  assert_true(first.with_mask(@mooninput.pattern("##").unwrap()) is Err(_))
  assert_eq(first.display(), "12-34")
  let amount = @mooninput.number(radix=',', group_separator=" ").unwrap()
  assert_eq(@mooninput.pipe(amount, "1234,50"), Ok("1 234,50"))
  assert_eq(@mooninput.pipe(amount, "1234,50", unmask=true), Ok("1234.50"))
  assert_true(@mooninput.pipe(amount, "-", unmask=true) is Err(_))
  let date = @mooninput.date(format="DD/MM/YYYY").unwrap()
  assert_eq(@mooninput.pipe(date, "29022024", unmask=true), Ok("2024-02-29"))
}
