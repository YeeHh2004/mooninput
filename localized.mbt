///|
fn compare_decimal(a : String, b : String) -> Int {
  fn split(value : String) -> (Bool, Array[Char], Array[Char]) {
    let chars = value.to_array()
    let mut dot = chars.length()
    for i, c in chars {
      if c == '.' {
        dot = i
        break
      }
    }
    let negative = chars.length() > 0 && chars[0] == '-'
    let mut start = if negative { 1 } else { 0 }
    while start + 1 < dot && chars[start] == '0' {
      start += 1
    }
    let integer : Array[Char] = []
    for i in start..<dot {
      integer.push(chars[i])
    }
    if integer.is_empty() {
      integer.push('0')
    }
    let fraction : Array[Char] = []
    for i in (dot + 1)..<chars.length() {
      fraction.push(chars[i])
    }
    let mut nonzero = false
    for c in integer {
      if c != '0' {
        nonzero = true
      }
    }
    for c in fraction {
      if c != '0' {
        nonzero = true
      }
    }
    (negative && nonzero, integer, fraction)
  }
  let (an, ai, af) = split(a)
  let (bn, bi, bf) = split(b)
  if an != bn {
    return if an { -1 } else { 1 }
  }
  let direction = if an { -1 } else { 1 }
  if ai.length() != bi.length() {
    return if ai.length() < bi.length() { -direction } else { direction }
  }
  for i in 0..<ai.length() {
    if ai[i] != bi[i] {
      return if ai[i] < bi[i] { -direction } else { direction }
    }
  }
  for i in 0..<af.length().max(bf.length()) {
    let ac = if i < af.length() { af[i] } else { '0' }
    let bc = if i < bf.length() { bf[i] } else { '0' }
    if ac != bc {
      return if ac < bc { -direction } else { direction }
    }
  }
  0
}

///|
/// Locale-configurable exact decimal input. Bounds and values stay decimal strings.
pub fn number(
  precision? : Int = 2,
  signed? : Bool = true,
  radix? : Char = '.',
  group_separator? : String = ",",
  map_radix? : String = "",
  min? : String = "",
  max? : String = "",
  pad_fraction? : Bool = false,
  normalize_zeros? : Bool = false,
  autofix? : Bool = false,
) -> Result[Mask, InputError] {
  if precision < 0 || precision > 18 {
    return Err(InvalidConfig("precision must be between 0 and 18"))
  }
  if !radix.is_printable() || radix.is_ascii_digit() || radix == '-' {
    return Err(InvalidConfig("invalid radix"))
  }
  let separators = group_separator.to_array()
  if separators.length() > 1 {
    return Err(InvalidConfig("group separator must be empty or one scalar"))
  }
  if separators.length() == 1 &&
    (
      !separators[0].is_printable() ||
      separators[0] == radix ||
      separators[0].is_ascii_digit() ||
      separators[0] == '-'
    ) {
    return Err(InvalidConfig("invalid group separator"))
  }
  for c in map_radix {
    if !c.is_printable() ||
      c.is_ascii_digit() ||
      c == '-' ||
      group_separator.contains_char(c) {
      return Err(
        InvalidConfig("radix mapping conflicts with grouping or digits"),
      )
    }
  }
  fn bound(text : String) -> Result[String, InputError] {
    if text == "" {
      return Ok("")
    }
    match parse_decimal(text, precision, signed, false) {
      Ok(r) =>
        if decimal_status(r.raw) == Complete {
          Ok(decimal_value(r.raw))
        } else {
          Err(InvalidConfig("incomplete numeric bound"))
        }
      Err(_) => Err(InvalidConfig("invalid numeric bound"))
    }
  }
  let lower = match bound(min) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let upper = match bound(max) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if lower != "" && upper != "" && compare_decimal(lower, upper) > 0 {
    return Err(InvalidConfig("min exceeds max"))
  }
  fn parse(text : String, enforce_bounds : Bool) -> Result[Render, InputError] {
    if text.length() > 512 {
      return Err(TooLong(512))
    }
    let mut internal = ""
    let mut normalized_input = ""
    let mut grouped = false
    for c in text {
      if group_separator != "" && group_separator.contains_char(c) {
        grouped = true
        normalized_input += group_separator
        continue
      }
      if c == radix || map_radix.contains_char(c) {
        internal += "."
        normalized_input += radix.to_string()
      } else {
        if !c.is_ascii_digit() && c != '-' {
          return Err(InvalidCharacter(internal.length(), c.to_string()))
        }
        internal += c.to_string()
        normalized_input += c.to_string()
      }
    }
    let initial = match parse_decimal(internal, precision, signed, false) {
      Ok(r) => r
      Err(e) => return Err(e)
    }
    let mut raw = initial.raw
    let mut state = decimal_status(raw)
    let mut canonical = if state == Complete {
      decimal_value(raw)
    } else {
      internal
    }
    let mut dot = raw.length()
    for i, c in raw {
      if c == '.' {
        dot = i
        break
      }
    }
    let sign = if raw.length() > 0 && raw[0] == '-' { 1 } else { 0 }
    let mut before_padding = ""
    for i, c in raw {
      if group_separator != "" && i > sign && i < dot && (dot - i) % 3 == 0 {
        before_padding += group_separator
      }
      before_padding += if c == '.' { radix.to_string() } else { c.to_string() }
    }
    if grouped && before_padding != normalized_input {
      return Err(InvalidValue("malformed digit grouping"))
    }
    if state == Complete {
      let outside = if enforce_bounds &&
        lower != "" &&
        compare_decimal(canonical, lower) < 0 {
        Some(lower)
      } else if enforce_bounds &&
        upper != "" &&
        compare_decimal(canonical, upper) > 0 {
        Some(upper)
      } else {
        None
      }
      if outside is Some(limit) {
        if autofix {
          canonical = limit
          raw = limit.to_array()
        } else {
          state = Invalid("number is outside configured bounds")
        }
      }
      if normalize_zeros {
        let chars = canonical.to_array()
        let mut stop = chars.length()
        if canonical.contains_char('.') {
          while stop > 0 && chars[stop - 1] == '0' {
            stop -= 1
          }
          if stop > 0 && chars[stop - 1] == '.' {
            stop -= 1
          }
        }
        canonical = String::from_array(chars[:stop].to_owned())
      }
      if pad_fraction && precision > 0 {
        let mut count = 0
        let mut after = false
        for c in canonical {
          if c == '.' {
            after = true
          } else if after {
            count += 1
          }
        }
        if !after {
          canonical += "."
        }
        for _ in count..<precision {
          canonical += "0"
        }
      }
    }
    if enforce_bounds && state == Complete && canonical.length() > 256 {
      return Err(TooLong(256))
    }
    dot = raw.length()
    for i, c in raw {
      if c == '.' {
        dot = i
        break
      }
    }
    let sign = if raw.length() > 0 && raw[0] == '-' { 1 } else { 0 }
    let starts : Array[Int] = []
    let ends : Array[Int] = []
    let localized_raw : Array[Char] = []
    let mut display = ""
    for i, c in raw {
      if group_separator != "" && i > sign && i < dot && (dot - i) % 3 == 0 {
        display += group_separator
      }
      let localized = if c == '.' { radix } else { c }
      starts.push(display.length())
      display += localized.to_string()
      ends.push(display.length())
      localized_raw.push(localized)
    }
    Ok({
      ..make_render(localized_raw, display, starts, ends),
      state: Some(state),
      canonical: Some(canonical),
    })
  }
  Ok(
    extension(text => parse(text, true), capacity=256, fragment=text => {
      match parse(text, false) {
        Ok(r) => Ok(r.raw)
        Err(e) => Err(e)
      }
    }),
  )
}

///|
/// Configurable Gregorian date ordering and inclusive ISO date bounds.
pub fn date(
  format? : String = "YYYY-MM-DD",
  min? : String = "0001-01-01",
  max? : String = "9999-12-31",
) -> Result[Mask, InputError] {
  if format.length() > 128 {
    return Err(InvalidConfig("date format is too long"))
  }
  let chars = format.to_array()
  for c in chars {
    if !c.is_printable() {
      return Err(InvalidConfig("date format literals must be printable"))
    }
  }
  let mut source = ""
  let mut last_source = ""
  let mut suffix = ""
  let order : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == 'Y' || c == 'M' || c == 'D' {
      let count = if c == 'Y' { 4 } else { 2 }
      if order.contains(c) || i + count > chars.length() {
        return Err(InvalidConfig("date format requires one YYYY, MM and DD"))
      }
      for j in 0..<count {
        if chars[i + j] != c {
          return Err(InvalidConfig("date field width is invalid"))
        }
        source += "#"
      }
      order.push(c)
      i += count
      last_source = source
      suffix = ""
    } else {
      if c == '#' ||
        c == 'A' ||
        c == 'X' ||
        c == '*' ||
        c == '[' ||
        c == ']' ||
        c == '\\' {
        source += "\\"
      }
      source += c.to_string()
      suffix += c.to_string()
      i += 1
    }
  }
  if order.length() != 3 {
    return Err(InvalidConfig("date format requires YYYY, MM and DD"))
  }
  let base = match pattern(last_source) {
    Ok(m) => m
    Err(_) => return Err(InvalidConfig("invalid date format literals"))
  }
  fn key(value : String) -> Result[Int, InputError] {
    match Editor::new(iso_date(), initial=value) {
      Ok(e) =>
        if e.status() == Complete {
          Ok(date_digits(e.raw()))
        } else {
          Err(InvalidConfig("invalid date bound"))
        }
      Err(_) => Err(InvalidConfig("invalid date bound"))
    }
  }
  let lower = match key(min) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let upper = match key(max) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if lower > upper {
    return Err(InvalidConfig("date min exceeds max"))
  }
  fn parse(text : String) -> Result[Render, InputError] {
    let r = match base.render_input(text) {
      Ok(r) => r
      Err(original_error) => {
        if suffix == "" || !text.has_suffix(suffix) {
          return Err(original_error)
        }
        let chars = text.to_array()
        let content = String::from_array(
          chars[:chars.length() - suffix.to_array().length()].to_owned(),
        )
        match base.render_input(content) {
          Ok(r) => r
          Err(e) => return Err(e)
        }
      }
    }
    if r.raw.is_empty() {
      return Ok({ ..r, state: Some(Empty), })
    }
    if r.raw.length() < 8 {
      return Ok({ ..r, state: Some(Incomplete), })
    }
    let mut offset = 0
    let mut year = ""
    let mut month = ""
    let mut day = ""
    for c in order {
      let count = if c == 'Y' { 4 } else { 2 }
      let mut value = ""
      for j in 0..<count {
        value += r.raw[offset + j].to_string()
      }
      match c {
        'Y' => year = value
        'M' => month = value
        _ => day = value
      }
      offset += count
    }
    let canonical = year + "-" + month + "-" + day
    let iso = Editor::new(iso_date(), initial=canonical).unwrap()
    let mut state = iso.status()
    if state == Complete {
      let value = date_digits(year + month + day)
      if value < lower || value > upper {
        state = Invalid("date is outside configured bounds")
      }
    }
    Ok({
      ..r,
      display: r.display + suffix,
      state: Some(state),
      canonical: Some(canonical),
      fields: [
        { name: "year", value: year, },
        { name: "month", value: month, },
        { name: "day", value: day, },
      ],
    })
  }
  Ok(extension(parse, capacity=8))
}

///|
fn date_digits(text : String) -> Int {
  let mut result = 0
  for c in text {
    result = result * 10 + c.to_int() - 48
  }
  result
}
