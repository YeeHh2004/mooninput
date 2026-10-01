///|
/// Decimal text editing. Precision limits fractional digits; it never rounds.
/// Uses '.' as radix and optional ',' grouping. At most 256 raw characters.
pub fn decimal(
  precision? : Int = 2,
  signed? : Bool = false,
  grouped? : Bool = true,
) -> Result[Mask, InputError] {
  if precision < 0 || precision > 18 {
    return Err(InvalidConfig("precision must be between 0 and 18"))
  }
  Ok({ kind: DecimalKind(precision, signed, grouped), })
}

///|
fn decimal_chars(
  text : String,
  grouped : Bool,
) -> Result[Array[Char], InputError] {
  if text.length() > 512 {
    return Err(TooLong(512))
  }
  let chars : Array[Char] = []
  for c in text {
    if c == ',' && grouped {
      continue
    }
    if !c.is_ascii_digit() && c != '.' && c != '-' {
      return Err(InvalidCharacter(chars.length(), c.to_string()))
    }
    chars.push(c)
  }
  Ok(chars)
}

///|
fn render_decimal(
  raw : Array[Char],
  precision : Int,
  signed : Bool,
  grouped : Bool,
) -> Result[Render, InputError] {
  if raw.length() > 256 {
    return Err(TooLong(256))
  }
  let mut dot = raw.length()
  let sign = if raw.length() > 0 && raw[0] == '-' { 1 } else { 0 }
  if sign == 1 && !signed {
    return Err(InvalidCharacter(0, "-"))
  }
  for i, c in raw {
    if c == '.' {
      if dot != raw.length() || precision == 0 {
        return Err(InvalidCharacter(i, "."))
      }
      dot = i
    } else if c == '-' && i == 0 {
      ()
    } else if !c.is_ascii_digit() {
      return Err(InvalidCharacter(i, c.to_string()))
    }
  }
  if dot < raw.length() && raw.length() - dot - 1 > precision {
    return Err(InvalidValue("fraction exceeds configured precision"))
  }
  let starts : Array[Int] = []
  let ends : Array[Int] = []
  let mut display = ""
  for i, c in raw {
    if grouped && i > sign && i < dot && (dot - i) % 3 == 0 {
      display += ","
    }
    starts.push(display.length())
    display += c.to_string()
    ends.push(display.length())
  }
  Ok({ raw, display, starts, ends, })
}

///|
fn parse_decimal(
  text : String,
  precision : Int,
  signed : Bool,
  grouped : Bool,
) -> Result[Render, InputError] {
  let chars = match decimal_chars(text, grouped) {
    Ok(chars) => chars
    Err(e) => return Err(e)
  }
  match render_decimal(chars, precision, signed, grouped) {
    Err(e) => Err(e)
    Ok(render) => {
      if text.contains_char(',') && render.display != text {
        return Err(InvalidValue("malformed digit grouping"))
      }
      Ok(render)
    }
  }
}

///|
fn decimal_status(raw : Array[Char]) -> Status {
  if raw.is_empty() {
    return Empty
  }
  if raw[raw.length() - 1] == '.' || raw[raw.length() - 1] == '-' {
    return Incomplete
  }
  Complete
}

///|
fn decimal_value(raw : Array[Char]) -> String {
  let negative = raw[0] == '-'
  let mut i = if negative { 1 } else { 0 }
  while i + 1 < raw.length() && raw[i] == '0' && raw[i + 1].is_ascii_digit() {
    i += 1
  }
  let mut value = if negative { "-" } else { "" }
  if raw[i] == '.' {
    value += "0"
  }
  while i < raw.length() {
    value += raw[i].to_string()
    i += 1
  }
  value
}
