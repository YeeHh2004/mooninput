///|
fn date(value : String) -> @mooninput.Editor {
  @mooninput.Editor::new(@mooninput.iso_date(), initial=value).unwrap()
}

///|
test "date accepts raw and formatted paste with canonical value" {
  assert_eq(date("20261002").display(), "2026-10-02")
  assert_eq(date("2026-10-02").raw(), "20261002")
  assert_eq(date("20261002").value(), Ok("2026-10-02"))
}

///|
test "Gregorian leap century rules" {
  for
    value in [
      "2000-02-29", "2024-02-29", "2400-02-29", "0001-01-01", "9999-12-31",
    ] {
    assert_eq(date(value).status(), @mooninput.Complete)
  }
  for
    value in [
      "1900-02-29", "2100-02-29", "2025-02-29", "2024-04-31", "2024-00-01", "2024-13-01",
      "2024-01-00", "0000-01-01",
    ] {
    match date(value).status() {
      @mooninput.Invalid(_) => ()
      _ => fail("invalid calendar date accepted: " + value)
    }
  }
}

///|
test "invalid date remains editable and can be repaired" {
  let before = date("20230229")
  assert_eq(before.display(), "2023-02-29")
  assert_eq(
    before.value(),
    Err(@mooninput.InvalidValue("day is outside this month")),
  )
  let after = before.select(3, 4).unwrap().insert("4").unwrap()
  assert_eq(after.value(), Ok("2024-02-29"))
  assert_eq(before.display(), "2023-02-29")
}

///|
test "date partial states do not force premature calendar validity" {
  assert_eq(date("").status(), @mooninput.Empty)
  assert_eq(date("2026").status(), @mooninput.Incomplete)
  assert_eq(date("202613").status(), @mooninput.Incomplete)
  assert_eq(date("2026-1").display(), "2026-1")
  assert_eq(
    date("20261002").select(5, 5).unwrap().backspace().unwrap().display(),
    "2021-00-2",
  )
}
