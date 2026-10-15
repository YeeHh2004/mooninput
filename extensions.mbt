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
) -> Mask {
  { kind: ExtensionKind({ parse, capacity: Some(capacity), }), }
}

///|
fn enrich_render(render : Render, mask : Mask) -> Render {
  let end = render.display.length()
  let editor : Editor = { mask, render, selection: { start: end, end, }, }
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
/// Change rules atomically. The previous raw value is revalidated by the new mask.
pub fn Editor::with_mask(
  self : Editor,
  mask : Mask,
) -> Result[Editor, InputError] {
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
