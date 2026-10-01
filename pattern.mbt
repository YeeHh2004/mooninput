///|
/// Compile # digit, A ASCII letter, * ASCII alphanumeric, X printable scalar.
/// A single optional suffix in brackets is supported. Backslash escapes literals.
pub fn pattern(source : String) -> Result[Mask, InputError] {
  if source.length() > 4096 {
    return Err(TooLong(4096))
  }
  let chars = source.to_array()
  let slots : Array[Slot] = []
  let prefixes : Array[String] = []
  let mut prefix = ""
  let mut optional = false
  let mut closed = false
  let mut required = 0
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if closed {
      return Err(InvalidPattern("optional group must be a suffix"))
    }
    if c == '\\' {
      i += 1
      if i == chars.length() {
        return Err(InvalidPattern("trailing escape"))
      }
      if !chars[i].is_printable() {
        return Err(InvalidPattern("control literal"))
      }
      prefix += chars[i].to_string()
    } else if c == '[' {
      if optional {
        return Err(InvalidPattern("nested optional group"))
      }
      optional = true
      required = slots.length()
    } else if c == ']' {
      if !optional {
        return Err(InvalidPattern("unexpected closing bracket"))
      }
      if slots.length() == required {
        return Err(InvalidPattern("empty optional group"))
      }
      closed = true
    } else {
      let slot = match c {
        '#' => Some(Digit)
        'A' => Some(Letter)
        '*' => Some(Alnum)
        'X' => Some(Printable)
        _ => None
      }
      match slot {
        Some(s) => {
          slots.push(s)
          prefixes.push(prefix)
          prefix = ""
        }
        None => {
          if !c.is_printable() {
            return Err(InvalidPattern("control literal"))
          }
          prefix += c.to_string()
        }
      }
    }
    i += 1
  }
  if slots.is_empty() {
    return Err(InvalidPattern("at least one slot is required"))
  }
  if optional && !closed {
    return Err(InvalidPattern("unclosed optional group"))
  }
  if prefix != "" {
    return Err(InvalidPattern("trailing literals are not supported"))
  }
  if !optional {
    required = slots.length()
  }
  Ok({ kind: PatternKind({ slots, prefixes, required, }), })
}

///|
fn parse_raw(
  p : Pattern,
  text : Array[Char],
  start : Int,
) -> Result[Array[Char], InputError] {
  if text.length() + start > p.slots.length() {
    return Err(TooLong(p.slots.length()))
  }
  let result : Array[Char] = []
  for i, c in text {
    match p.slots[start + i].accept(c) {
      Some(value) => result.push(value)
      None => return Err(InvalidCharacter(start + i, c.to_string()))
    }
  }
  Ok(result)
}

///|
fn matches_at(text : Array[Char], offset : Int, prefix : Array[Char]) -> Bool {
  if offset + prefix.length() > text.length() {
    return false
  }
  for j, c in prefix {
    if text[offset + j] != c {
      return false
    }
  }
  true
}

///|
fn parse_pattern(
  p : Pattern,
  text : String,
  start : Int,
) -> Result[Array[Char], InputError] {
  if text.length() > 8192 {
    return Err(TooLong(8192))
  }
  let chars = text.to_array()
  // Raw input takes precedence where a literal could also be a valid slot value.
  match parse_raw(p, chars, start) {
    Ok(result) => return Ok(result)
    Err(_) => ()
  }
  let result : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    let slot = start + result.length()
    if slot >= p.slots.length() {
      return Err(TooLong(p.slots.length()))
    }
    let prefix = p.prefixes[slot].to_array()
    if !prefix.is_empty() && matches_at(chars, i, prefix) {
      i += prefix.length()
      if i == chars.length() {
        break
      }
    }
    match p.slots[slot].accept(chars[i]) {
      Some(value) => result.push(value)
      None => return Err(InvalidCharacter(slot, chars[i].to_string()))
    }
    i += 1
  }
  Ok(result)
}

///|
fn render_pattern(p : Pattern, raw : Array[Char]) -> Render {
  let starts : Array[Int] = []
  let ends : Array[Int] = []
  let mut display = ""
  for i, c in raw {
    display += p.prefixes[i]
    starts.push(display.length())
    display += c.to_string()
    ends.push(display.length())
  }
  { raw, display, starts, ends, }
}

///|
/// Normalize a raw or exactly formatted value. Does not allocate an editor.
pub fn Mask::format(self : Mask, text : String) -> Result[String, InputError] {
  match self.kind {
    PatternKind(p) | DateKind(p) =>
      match parse_pattern(p, text, 0) {
        Ok(raw) => Ok(render_pattern(p, raw).display)
        Err(e) => Err(e)
      }
    DecimalKind(_, _, _) => Err(InvalidConfig("decimal implementation pending"))
  }
}
