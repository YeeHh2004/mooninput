///|
test "acceptance date numeric suffix keeps raw first and formatted fallback interpretations" {
  let mask = @mooninput.date(format="YYYY-MM-DD1").unwrap()
  let raw = @mooninput.Editor::new(mask, initial="20240101").unwrap()
  assert_eq(raw.status(), @mooninput.Complete)
  assert_eq(raw.value(), Ok("2024-01-01"))
  assert_eq(raw.display(), "2024-01-011")
  assert_eq(mask.format("2024-01-011"), Ok("2024-01-011"))
}

///|
test "acceptance date rejects control literals consistently at every format position" {
  for control in ["\n", "\r", "\t", "\u0000"] {
    assert_true(@mooninput.date(format="YYYY-MM-DD" + control) is Err(_))
    assert_true(@mooninput.date(format=control + "YYYY-MM-DD") is Err(_))
    assert_true(@mooninput.date(format="YYYY" + control + "MM-DD") is Err(_))
  }
}

///|
test "acceptance padded numeric canonical values round trip at resource boundaries" {
  for precision in [1, 2, 18] {
    let mask = @mooninput.number(
      precision~,
      group_separator="",
      pad_fraction=true,
    ).unwrap()
    for length in [237, 253, 254, 255, 256] {
      let text = String::make(length, '1')
      match @mooninput.Editor::new(mask, initial=text) {
        Err(@mooninput.TooLong(_)) => ()
        Ok(editor) => {
          assert_eq(editor.status(), @mooninput.Complete)
          let committed = editor.commit(fn(value) { value }).unwrap()
          assert_eq(committed.value(), editor.value())
        }
        Err(error) => fail("unexpected numeric error: \{error.message()}")
      }
    }
  }
}

///|
test "acceptance localized exact canonical values round trip across distinct locale alphabets" {
  for
    (radix, separator) in [
      ('.', ","),
      (',', "."),
      (',', " "),
      ('·', "_"),
      ('😀', "🚀"),
    ] {
    let mask = @mooninput.number(
      precision=18,
      radix~,
      group_separator=separator,
      normalize_zeros=true,
      pad_fraction=true,
    ).unwrap()
    for
      canonical in [
        "0", "-0", "1234.125", "-9007199254740993.000000000000000001", "999999999999999999999999.123456789012345678",
      ] {
      let localized = String::from_array(
        canonical.to_array().map(fn(c) { if c == '.' { radix } else { c } }),
      )
      let editor = @mooninput.Editor::new(mask, initial=localized).unwrap()
      let expected = editor.value().unwrap()
      let from_display = @mooninput.Editor::new(mask, initial=editor.display()).unwrap()
      assert_eq(from_display.value(), Ok(expected))
      let committed = editor
        .commit(fn(value) {
          String::from_array(
            value.to_array().map(fn(c) { if c == '.' { radix } else { c } }),
          )
        })
        .unwrap()
      assert_eq(committed.value(), Ok(expected))
    }
  }
}

///|
test "acceptance regex prefixes fit their eventual UTF16 continuation" {
  let mask = @mooninput.regex("a+😀").unwrap()
  let fit = String::make(8190, 'a')
  assert_eq(
    @mooninput.Editor::new(mask, initial=fit).unwrap().status(),
    @mooninput.Incomplete,
  )
  assert_eq(mask.format(fit + "😀"), Ok(fit + "😀"))
  assert_true(mask.format(String::make(8191, 'a')) is Err(_))
}

///|
test "acceptance regex mixed scalar and UTF16 limits use one feasible continuation" {
  let mask = @mooninput.regex("a+c(😀😀|bbb)", max_length=8191).unwrap()
  let prefix = String::make(8188, 'a')
  // One branch fits the scalar budget, the other fits the UTF-16 budget, but
  // neither branch can satisfy both budgets after this extra common 'c'.
  assert_true(mask.format(prefix) is Err(_))
  let fit = String::make(8187, 'a')
  assert_eq(
    @mooninput.Editor::new(mask, initial=fit).unwrap().status(),
    @mooninput.Incomplete,
  )
  assert_eq(mask.format(fit + "c😀😀"), Ok(fit + "c😀😀"))
  assert_eq(mask.format(fit + "cbbb"), Ok(fit + "cbbb"))
}

///|
test "acceptance regex Unicode prefix limits agree with an independent finite word oracle" {
  let cases : Array[(String, Array[String])] = [
    ("c(😀😀|bbb)", ["c😀😀", "cbbb"]),
    ("(?:😀|bc)d?", ["😀", "😀d", "bc", "bcd"]),
    (
      "c([ab]😀){1,2}",
      [
        "ca😀", "cb😀", "ca😀a😀", "ca😀b😀", "cb😀a😀", "cb😀b😀",
      ],
    ),
    ("(?:cd|😀){2}", ["cdcd", "cd😀", "😀cd", "😀😀"]),
    ("😀{1,3}", ["😀", "😀😀", "😀😀😀"]),
  ]
  for (source, words) in cases {
    for count in 8184..<8192 {
      let prefix = String::make(count, 'a')
      for budget in 0..<=8 {
        if count + budget > 8192 {
          continue
        }
        let mut viable = false
        for word in words {
          if word.to_array().length() <= budget && count + word.length() <= 8192 {
            viable = true
          }
        }
        let mask = @mooninput.regex("a+" + source, max_length=count + budget).unwrap()
        assert_eq(mask.format(prefix) is Ok(_), viable)
      }
    }
  }
}

///|
test "acceptance regex conflicting resource analysis has an explicit work budget" {
  let mask = @mooninput.regex(
    "a+(?:(?:(?:c?){250}){2})*(?:(?:😀{200}){2}|(?:b{200}){3})",
    max_length=7992,
  ).unwrap()
  // The emoji suffix needs 800 units; the ASCII suffix needs 600 scalars.
  // Remaining budgets are only 799 units and 599 scalars. Nullable cycles
  // cannot improve either budget, and analysis must remain bounded.
  match mask.format(String::make(7393, 'a')) {
    Err(@mooninput.InvalidValue(reason)) =>
      assert_true(reason.contains("bounded work budget"))
    _ => fail("constrained analysis must report its explicit budget exhaustion")
  }
}

///|
test "acceptance regex rejects malformed UTF16 from host strings on both targets" {
  for code in [0xD800, 0xDBFF, 0xDC00, 0xDFFF] {
    let malformed = String::from_array([code.unsafe_to_char()])
    assert_true(@mooninput.regex(malformed) is Err(_))
    for source in [".", "[^]", "[\\u0000-\\u{10FFFF}]"] {
      let mask = @mooninput.regex(source).unwrap()
      assert_true(mask.format(malformed) is Err(_))
    }
  }
  assert_eq(@mooninput.regex("😀").unwrap().format("😀"), Ok("😀"))
}

///|
test "acceptance numeric fragment paste normalizes grouping without clamping fragments" {
  for (radix, separator) in [('.', ","), (',', ".")] {
    let mask = @mooninput.number(
      radix~,
      group_separator=separator,
      min="1000",
      max="9999999",
      autofix=true,
    ).unwrap()
    let source = "1234" + radix.to_string() + "50"
    let editor = @mooninput.Editor::new(mask, initial=source).unwrap()
    let pasted = "5" + separator + "678"
    let expanded = editor.select(2, 3).unwrap().insert(pasted).unwrap()
    assert_eq(expanded.value(), Ok("1567834.50"))
    let replaced = editor.select(2, 3).unwrap().insert("5").unwrap()
    assert_eq(replaced.value(), Ok("1534.50"))
    let fraction = editor.select(6, 8).unwrap().insert("00").unwrap()
    assert_eq(fraction.value(), Ok("1234.00"))
    let clamped = editor.select(0, 8).unwrap().insert("0").unwrap()
    assert_eq(clamped.value(), Ok("1000"))
  }
}

///|
test "acceptance preparation sees the complete proposal before numeric validation" {
  let prepared = @mooninput.with_prepare(
    @mooninput.number(group_separator="").unwrap(),
    text => text.trim().to_owned(),
  )
  let masks = [
    prepared,
    @mooninput.with_validation(prepared, _ => @mooninput.Complete),
    @mooninput.with_value(prepared, text => text),
    @mooninput.presentation(prepared).unwrap(),
  ]
  for mask in masks {
    let editor = @mooninput.Editor::new(mask, initial="12").unwrap()
    assert_eq(editor.insert("3 ").unwrap().value(), Ok("123"))
    assert_eq(
      editor.select(0, 2).unwrap().insert(" 34 ").unwrap().value(),
      Ok("34"),
    )
    assert_eq(editor.value(), Ok("12"))
  }
}

///|
test "acceptance pattern wrappers preserve formatted overwrite counts and insertion slots" {
  let base = @mooninput.pattern("##-##-##").unwrap()
  let masks = [
    @mooninput.with_validation(base, _ => @mooninput.Complete),
    @mooninput.with_value(base, text => text),
    @mooninput.presentation(base).unwrap(),
    @mooninput.with_prepare(base, text => text),
  ]
  for mask in masks {
    let editor = @mooninput.Editor::new(mask, initial="123456").unwrap()
    let overwritten = editor
      .select(0, 0)
      .unwrap()
      .insert("98-76", overwrite=true)
      .unwrap()
    assert_eq(overwritten.display(), "98-76-56")
    assert_eq(overwritten.value(), Ok("987656"))
  }
  let mixed = @mooninput.pattern("AA-##").unwrap()
  let wrappers = [
    @mooninput.with_validation(mixed, _ => @mooninput.Complete),
    @mooninput.with_value(mixed, text => text),
    @mooninput.presentation(mixed).unwrap(),
  ]
  for mask in wrappers {
    let editor = @mooninput.Editor::new(mask, initial="AB12").unwrap()
    assert_eq(
      editor.select(3, 5).unwrap().insert("34").unwrap().value(),
      Ok("AB34"),
    )
    assert_eq(
      editor.select(3, 3).unwrap().insert("34", overwrite=true).unwrap().value(),
      Ok("AB34"),
    )
  }
}

///|
test "acceptance numeric fragment padding limits are enforced after whole value autofix" {
  let base = @mooninput.number(
    group_separator="",
    max="100",
    autofix=true,
    pad_fraction=true,
  ).unwrap()
  let masks = [
    base,
    @mooninput.with_validation(base, _ => @mooninput.Complete),
    @mooninput.with_value(base, text => text),
    @mooninput.presentation(base).unwrap(),
  ]
  let huge = String::make(256, '9')
  for mask in masks {
    let editor = @mooninput.Editor::new(mask, initial="12").unwrap()
    assert_eq(editor.set_value(huge).unwrap().value(), Ok("100.00"))
    let pasted = editor.select(0, 2).unwrap().insert(huge).unwrap()
    assert_eq(pasted.value(), Ok("100.00"))
    assert_eq(editor.value(), Ok("12.00"))
  }
}

///|
test "acceptance transparent numeric wrappers retain genuine grouping fragment hooks" {
  let base = @mooninput.number(
    radix=',',
    group_separator=".",
    min="1000",
    max="9999999",
    autofix=true,
  ).unwrap()
  let masks = [
    @mooninput.with_validation(base, _ => @mooninput.Complete),
    @mooninput.with_value(base, text => text),
    @mooninput.presentation(base).unwrap(),
  ]
  for mask in masks {
    let editor = @mooninput.Editor::new(mask, initial="1234,50").unwrap()
    assert_eq(
      editor.select(2, 3).unwrap().insert("5.678").unwrap().value(),
      Ok("1567834.50"),
    )
    assert_eq(
      editor.select(6, 8).unwrap().insert("00").unwrap().value(),
      Ok("1234.00"),
    )
  }
}
