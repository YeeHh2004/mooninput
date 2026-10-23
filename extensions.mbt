///|
fn make_render(
  raw : Array[Char],
  display : String,
  starts : Array[Int],
  ends : Array[Int],
) -> Render {
  {
    raw,
    display,
    starts,
    ends,
    state: None,
    canonical: None,
    active: None,
    fields: [],
    reconcile_by_edit: false,
  }
}

///|
fn text_render(
  text : String,
  status : Status,
  value? : String = text,
  active? : String = "",
  fields? : Array[FieldValue] = [],
) -> Render {
  let starts : Array[Int] = []
  let ends : Array[Int] = []
  for offset, c in text.iter2() {
    starts.push(offset)
    ends.push(offset + c.utf16_len())
  }
  {
    raw: text.to_array(),
    display: text,
    starts,
    ends,
    state: Some(status),
    canonical: Some(value),
    active: if active == "" {
      None
    } else {
      Some(active)
    },
    fields: fields.copy(),
    reconcile_by_edit: false,
  }
}

///|
fn extension(
  parse : (String) -> Result[Render, InputError],
  capacity? : Int = 8192,
  fragment? : (String) -> Result[Array[Char], InputError],
) -> Mask {
  { kind: ExtensionKind({ parse, capacity: Some(capacity), fragment, }), }
}

///|
fn Mask::fragment_normalizer(
  self : Mask,
) -> ((String) -> Result[Array[Char], InputError])? {
  match self.kind {
    ExtensionKind(e) => e.fragment
    DecimalKind(precision, signed, grouped) =>
      Some(text => {
        match parse_decimal(text, precision, signed, grouped) {
          Ok(render) => Ok(render.raw)
          Err(e) => Err(e)
        }
      })
    // Pattern fragments depend on the insertion slot. Absence retains the
    // existing whole-value parsing path instead of inventing a start-zero rule.
    _ => None
  }
}

///|
fn Mask::normalize_fragment(
  self : Mask,
  text : String,
) -> Result[Array[Char], InputError] {
  match self.fragment_normalizer() {
    Some(normalize) => normalize(text)
    None => Ok(text.to_array())
  }
}

///|
fn enrich_render(render : Render, mask : Mask) -> Render {
  let end = render.display.length()
  let editor : Editor = {
    mask,
    render,
    selection: { start: end, end, },
    replay: String::from_array(render.raw),
  }
  {
    ..render,
    state: Some(editor.status()),
    canonical: match editor.value() {
      Ok(v) => Some(v)
      Err(_) => None
    },
  }
}

///|
/// Define a single pattern token using MoonBit callbacks.
pub fn definition(
  token : Char,
  accept : (Char) -> Bool,
  normalize? : (Char) -> Char = c => c,
) -> Definition {
  { token, accept, normalize, }
}

///|
/// Maximum editable Unicode scalars, useful when composing masks.
pub fn Mask::capacity(self : Mask) -> Int {
  match self.kind {
    PatternKind(p) | DateKind(p) => p.slots.length()
    DecimalKind(_, _, _) => 256
    ExtensionKind(e) => e.capacity.unwrap_or(8192)
  }
}

///|
pub fn Editor::active_mask(self : Editor) -> String? {
  self.render.active
}

///|
pub fn Editor::fields(self : Editor) -> Array[FieldValue] {
  self.render.fields.copy()
}

///|
/// Change rules atomically. An unchanged interpretation preserves the replayed
/// snapshot; otherwise revalidate the old raw value and map its selection.
pub fn Editor::with_mask(
  self : Editor,
  mask : Mask,
) -> Result[Editor, InputError] {
  match
    Editor::restore(
      mask,
      self.raw(),
      self.display(),
      self.selection.start,
      self.selection.end,
      replay=self.replay_text(),
    ) {
    Ok(next) => return Ok(next)
    Err(_) => ()
  }
  let from = self.raw_index(self.selection.start).unwrap()
  let to = self.raw_index(self.selection.end).unwrap()
  match Editor::new(mask, initial=self.raw()) {
    Err(e) => Err(e)
    Ok(next) =>
      next.select(
        next.display_offset(from.min(next.render.raw.length())).unwrap(),
        next.display_offset(to.min(next.render.raw.length())).unwrap(),
      )
  }
}

///|
/// Convert text without maintaining an editor or DOM instance.
pub fn pipe(
  mask : Mask,
  text : String,
  unmask? : Bool = false,
) -> Result[String, InputError] {
  match Editor::new(mask, initial=text) {
    Err(e) => Err(e)
    Ok(editor) => if unmask { editor.value() } else { Ok(editor.display()) }
  }
}
