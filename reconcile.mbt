///|
/// Normalize a browser's already-edited display after composition/autofill.
/// Selection refers to the proposed display. Prefixes are formatted by the same
/// MoonBit core to map the caret, never by host-side formatting rules.
pub fn Editor::reconcile(
  self : Editor,
  text : String,
  start : Int,
  end : Int,
) -> Result[Editor, InputError] {
  if start < 0 || end < start || end > text.length() {
    return Err(InvalidSelection)
  }
  let next = match self.set_value(text) {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  let before_start : Array[Char] = []
  let before_end : Array[Char] = []
  for offset, c in text.iter2() {
    if offset + c.utf16_len() <= start {
      before_start.push(c)
    }
    if offset + c.utf16_len() <= end || (start != end && offset < end) {
      before_end.push(c)
    }
  }
  fn mapped(chars : Array[Char]) -> Int {
    let prefix = String::from_array(chars)
    match self.mask.kind {
      DecimalKind(_, _, grouped) =>
        match decimal_chars(prefix, grouped) {
          Ok(raw) => next.display_offset(raw.length()).unwrap_or(0)
          Err(_) => 0
        }
      PatternKind(p) | DateKind(p) =>
        match parse_pattern(p, prefix, 0) {
          Ok(raw) => next.display_offset(raw.length()).unwrap_or(0)
          Err(_) => 0
        }
    }
  }
  next.select(mapped(before_start), mapped(before_end))
}
