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
  let limit = match self.mask.kind {
    DecimalKind(_, _, _) => 512
    _ => 8192
  }
  if text.length() > limit {
    return Err(TooLong(limit))
  }
  if start < 0 || end < start || end > text.length() {
    return Err(InvalidSelection)
  }
  // An unchanged display already has a known raw interpretation. Re-parsing it
  // can turn literal characters into content for otherwise ambiguous masks.
  if text == self.display() {
    return self.select(start, end)
  }
  let next = match self.set_value(text) {
    Ok(e) => e
    Err(_) => {
      // Native input may leave previously generated separators in old positions.
      // Recover the single contiguous edit instead of treating that transient
      // display as a new, incorrectly grouped value.
      let old_chars = self.display().to_array()
      let new_chars = text.to_array()
      let mut prefix = 0
      while prefix < old_chars.length() &&
            prefix < new_chars.length() &&
            old_chars[prefix] == new_chars[prefix] {
        prefix += 1
      }
      let mut suffix = 0
      while suffix < old_chars.length() - prefix &&
            suffix < new_chars.length() - prefix &&
            old_chars[old_chars.length() - 1 - suffix] ==
            new_chars[new_chars.length() - 1 - suffix] {
        suffix += 1
      }
      let mut from = 0
      for i in 0..<prefix {
        from += old_chars[i].utf16_len()
      }
      let mut to = from
      for i in prefix..<(old_chars.length() - suffix) {
        to += old_chars[i].utf16_len()
      }
      let inserted : Array[Char] = []
      for i in prefix..<(new_chars.length() - suffix) {
        inserted.push(new_chars[i])
      }
      return match self.select(from, to) {
        Ok(selected) => selected.insert(String::from_array(inserted))
        Err(e) => Err(e)
      }
    }
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
