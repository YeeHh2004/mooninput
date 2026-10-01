///|
/// ISO Gregorian date input, years 0001..9999. Editing accepts partial dates;
/// completed invalid dates remain visible with Invalid status.
pub fn iso_date() -> Mask {
  let mask = pattern("####-##-##").unwrap()
  match mask.kind {
    PatternKind(p) => { kind: DateKind(p), }
    _ => abort("internal date pattern")
  }
}

///|
fn date_status(raw : Array[Char]) -> Status {
  if raw.is_empty() {
    return Empty
  }
  if raw.length() < 8 {
    return Incomplete
  }
  let mut year = 0
  for i in 0..<4 {
    year = year * 10 + raw[i].to_int() - 48
  }
  let month = (raw[4].to_int() - 48) * 10 + raw[5].to_int() - 48
  let day = (raw[6].to_int() - 48) * 10 + raw[7].to_int() - 48
  if year == 0 {
    return Invalid("year must be between 0001 and 9999")
  }
  if month < 1 || month > 12 {
    return Invalid("month must be between 01 and 12")
  }
  let leap = year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
  let days = match month {
    2 => if leap { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  if day < 1 || day > days {
    return Invalid("day is outside this month")
  }
  Complete
}
