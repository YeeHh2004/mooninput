///|
fn Mask::render_input(self : Mask, text : String) -> Result[Render, InputError] {
  match self.kind {
    PatternKind(p) | DateKind(p) =>
      match parse_pattern(p, text, 0) {
        Ok(raw) => Ok(render_pattern(p, raw))
        Err(e) => Err(e)
      }
    DecimalKind(_, _, _) => Err(InvalidConfig("decimal implementation pending"))
  }
}

///|
/// Create a snapshot from raw or formatted text. Selection starts at the end.
pub fn Editor::new(
  mask : Mask,
  initial? : String = "",
) -> Result[Editor, InputError] {
  match mask.render_input(initial) {
    Err(e) => Err(e)
    Ok(render) => {
      let end = render.display.length()
      Ok({ mask, render, selection: { start: end, end, }, })
    }
  }
}

///|
pub fn Editor::display(self : Editor) -> String {
  self.render.display
}

///|
/// Unformatted editable content; numeric input is kept as an exact string.
pub fn Editor::raw(self : Editor) -> String {
  String::from_array(self.render.raw)
}

///|
pub fn Editor::selection(self : Editor) -> Selection {
  self.selection
}

///|
pub fn Editor::status(self : Editor) -> Status {
  let n = self.render.raw.length()
  if n == 0 {
    return Empty
  }
  match self.mask.kind {
    PatternKind(p) | DateKind(p) =>
      if n == p.required || n == p.slots.length() {
        Complete
      } else {
        Incomplete
      }
    DecimalKind(_, _, _) => Incomplete
  }
}

///|
fn Render::snap(self : Render, offset : Int, upward : Bool) -> Int {
  for i, start in self.starts {
    let end = self.ends[i]
    if offset > start && offset < end {
      return if upward { end } else { start }
    }
  }
  // Also snap inside a supplementary literal, not only inside editable content.
  let mut previous = 0
  for boundary, c in self.display.iter2() {
    let next = boundary + c.utf16_len()
    if offset > boundary && offset < next {
      return if upward { next } else { boundary }
    }
    previous = next
  }
  offset.min(previous)
}

///|
/// Set a valid selection. A range expands to whole Unicode scalars;
/// a collapsed caret inside a surrogate pair snaps to its beginning.
pub fn Editor::select(
  self : Editor,
  start : Int,
  end : Int,
) -> Result[Editor, InputError] {
  if start < 0 || end < start || end > self.display().length() {
    return Err(InvalidSelection)
  }
  let s = self.render.snap(start, false)
  let e = self.render.snap(end, start != end)
  Ok({ ..self, selection: { start: s, end: e, }, })
}

///|
/// Map a display UTF-16 offset to an editable scalar index.
pub fn Editor::raw_index(
  self : Editor,
  offset : Int,
) -> Result[Int, InputError] {
  if offset < 0 || offset > self.display().length() {
    return Err(InvalidSelection)
  }
  let mut result = 0
  for end in self.render.ends {
    if end <= offset {
      result += 1
    } else {
      break
    }
  }
  Ok(result)
}

///|
/// Map an editable scalar boundary to a display UTF-16 position.
pub fn Editor::display_offset(
  self : Editor,
  index : Int,
) -> Result[Int, InputError] {
  if index < 0 || index > self.render.raw.length() {
    return Err(InvalidSelection)
  }
  Ok(if index == 0 { 0 } else { self.render.ends[index - 1] })
}

///|
fn Editor::replace_raw(
  self : Editor,
  start : Int,
  end : Int,
  text : String,
) -> Result[Editor, InputError] {
  let inserted = match self.mask.kind {
    PatternKind(p) | DateKind(p) => parse_pattern(p, text, start)
    DecimalKind(_, _, _) => Err(InvalidConfig("decimal implementation pending"))
  }
  let inserted = match inserted {
    Ok(chars) => chars
    Err(e) => return Err(e)
  }
  let raw : Array[Char] = []
  for i in 0..<start {
    raw.push(self.render.raw[i])
  }
  for c in inserted {
    raw.push(c)
  }
  for i in end..<self.render.raw.length() {
    raw.push(self.render.raw[i])
  }
  let rendered = match self.mask.kind {
    PatternKind(p) | DateKind(p) =>
      match parse_raw(p, raw, 0) {
        Ok(chars) => Ok(render_pattern(p, chars))
        Err(e) => Err(e)
      }
    DecimalKind(_, _, _) => Err(InvalidConfig("decimal implementation pending"))
  }
  match rendered {
    Err(e) => Err(e)
    Ok(render) => {
      let index = start + inserted.length()
      let caret = if index == 0 { 0 } else { render.ends[index - 1] }
      Ok({ mask: self.mask, render, selection: { start: caret, end: caret, }, })
    }
  }
}

///|
/// Replace the current selection or insert at the caret. Invalid edits are atomic.
pub fn Editor::insert(
  self : Editor,
  text : String,
) -> Result[Editor, InputError] {
  let start = self.raw_index(self.selection.start).unwrap()
  let end = self.raw_index(self.selection.end).unwrap()
  self.replace_raw(start, end, text)
}

///|
/// Delete selected raw characters, or the editable scalar before the caret.
pub fn Editor::backspace(self : Editor) -> Result[Editor, InputError] {
  let start = self.raw_index(self.selection.start).unwrap()
  let end = self.raw_index(self.selection.end).unwrap()
  if self.selection.start != self.selection.end {
    return self.replace_raw(start, end, "")
  }
  if start == 0 {
    return Ok(self)
  }
  self.replace_raw(start - 1, end, "")
}

///|
/// Delete selected raw characters, or the editable scalar after the caret.
pub fn Editor::delete_forward(self : Editor) -> Result[Editor, InputError] {
  let start = self.raw_index(self.selection.start).unwrap()
  let end = self.raw_index(self.selection.end).unwrap()
  if self.selection.start != self.selection.end {
    return self.replace_raw(start, end, "")
  }
  if end == self.render.raw.length() {
    return Ok(self)
  }
  self.replace_raw(start, end + 1, "")
}

///|
/// Replace all content and position the caret at the end.
pub fn Editor::set_value(
  self : Editor,
  text : String,
) -> Result[Editor, InputError] {
  Editor::new(self.mask, initial=text)
}

///|
/// Return a complete value, or a typed error. Empty is distinct from incomplete.
pub fn Editor::value(self : Editor) -> Result[String, InputError] {
  match self.status() {
    Empty => Err(InvalidValue("empty"))
    Incomplete => Err(InvalidValue("incomplete"))
    Invalid(reason) => Err(InvalidValue(reason))
    Complete => Ok(self.raw())
  }
}

///|
pub fn InputError::message(self : InputError) -> String {
  match self {
    InvalidPattern(reason) => "Invalid pattern: " + reason
    InvalidCharacter(index, c) => "Invalid character at slot \{index}: " + c
    TooLong(limit) => "Input exceeds limit \{limit}"
    InvalidSelection => "Selection is outside the displayed value"
    InvalidConfig(reason) => "Invalid configuration: " + reason
    InvalidValue(reason) => "Value is " + reason
  }
}
