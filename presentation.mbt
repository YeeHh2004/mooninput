///|
/// Copy a display while concealing editable scalars. Generated literals retain
/// their original spelling; starts/ends follow the replacement UTF-16 widths.
fn conceal_render(render : Render, concealed : Char) -> Render {
  let starts : Array[Int] = []
  let ends : Array[Int] = []
  let mut display = ""
  let mut editable = 0
  for offset, c in render.display.iter2() {
    if editable < render.raw.length() && offset == render.starts[editable] {
      starts.push(display.length())
      display += concealed.to_string()
      ends.push(display.length())
      editable += 1
    } else {
      display += c.to_string()
    }
  }
  { ..render, display, starts, ends, }
}

///|
fn present_pattern(
  render : Render,
  pattern : Pattern,
  placeholder : Char?,
  concealed : Char?,
  eager : Bool,
) -> Render {
  let starts : Array[Int] = []
  let ends : Array[Int] = []
  let mut display = ""
  for i, c in render.raw {
    display += pattern.prefixes[i]
    starts.push(display.length())
    display += concealed.unwrap_or(c).to_string()
    ends.push(display.length())
  }
  match placeholder {
    Some(c) =>
      for i in render.raw.length()..<pattern.slots.length() {
        display += pattern.prefixes[i]
        display += c.to_string()
      }
    None =>
      if eager && render.raw.length() < pattern.slots.length() {
        display += pattern.prefixes[render.raw.length()]
      }
  }
  { ..render, display, starts, ends, }
}

///|
/// Add display-only placeholders and/or conceal editable characters. Raw,
/// canonical values, validation, fields and active dynamic branches are retained.
/// Concealment is visual only: raw/canonical values remain available to callers.
/// Pattern/date placeholders include the complete literal layout. Other masks
/// append placeholders up to their declared scalar capacity. Eager generated
/// literals require a direct pattern/date mask and otherwise return an error.
/// Placeholder/concealment characters must be printable Unicode scalars.
pub fn presentation(
  mask : Mask,
  placeholder? : Char,
  concealed? : Char,
  eager? : Bool = false,
) -> Result[Mask, InputError] {
  match placeholder {
    Some(c) =>
      if !c.is_printable() {
        return Err(InvalidConfig("placeholder must be printable"))
      }
    None => ()
  }
  match concealed {
    Some(c) =>
      if !c.is_printable() {
        return Err(InvalidConfig("concealed character must be printable"))
      }
    None => ()
  }
  let layout = match mask.kind {
    PatternKind(p) | DateKind(p) => Some(p)
    _ => None
  }
  if eager && layout is None {
    return Err(
      InvalidConfig("eager literals require a direct pattern or date mask"),
    )
  }
  let capacity = mask.capacity()
  if capacity < 0 || capacity > 8192 {
    return Err(
      InvalidConfig("presentation capacity must not exceed 8192 scalars"),
    )
  }
  match placeholder {
    Some(c) =>
      if capacity * c.utf16_len() > 8192 {
        return Err(
          InvalidConfig("placeholder display exceeds 8192 UTF-16 units"),
        )
      }
    None => ()
  }
  Ok(
    extension(
      fn(text) {
        match mask.render_input(text) {
          Err(e) => Err(e)
          Ok(base) => {
            let base = enrich_render(base, mask)
            let render = match layout {
              Some(p) => present_pattern(base, p, placeholder, concealed, eager)
              None => {
                let hidden = match concealed {
                  Some(c) => conceal_render(base, c)
                  None => base
                }
                let mut display = hidden.display
                match placeholder {
                  Some(c) =>
                    for _ in hidden.raw.length()..<capacity {
                      display += c.to_string()
                    }
                  None => ()
                }
                { ..hidden, display, }
              }
            }
            if render.display.length() > 8192 {
              Err(TooLong(8192))
            } else {
              Ok({
                ..render,
                reconcile_by_edit: render.reconcile_by_edit ||
                placeholder is Some(_) ||
                concealed is Some(_),
              })
            }
          }
        }
      },
      capacity~,
      fragment?=mask.fragment_normalizer(),
    ),
  )
}

///|
/// Postprocess the canonical value of complete input without changing editable
/// raw content or display. Incomplete/invalid input never invokes the callback.
/// This is value postprocessing, not a deferred browser blur/commit event hook.
/// The callback must be deterministic and side-effect free; exceptions propagate.
pub fn with_value(mask : Mask, transform : (String) -> String) -> Mask {
  extension(
    fn(text) {
      match mask.render_input(text) {
        Err(e) => Err(e)
        Ok(base) => {
          let base = enrich_render(base, mask)
          if base.state is Some(Complete) {
            let value = transform(
              base.canonical.unwrap_or(String::from_array(base.raw)),
            )
            if value.length() > 8192 {
              Err(TooLong(8192))
            } else {
              Ok({ ..base, canonical: Some(value), })
            }
          } else {
            Ok(base)
          }
        }
      }
    },
    capacity=mask.capacity(),
    fragment?=mask.fragment_normalizer(),
  )
}

///|
/// Explicitly finalize a complete value through a callback, then atomically
/// revalidate the returned text with the same mask. The original snapshot is
/// unchanged on all paths. Unlike with_value, this can change editable content.
pub fn Editor::commit(
  self : Editor,
  transform : (String) -> String,
) -> Result[Editor, InputError] {
  let value = match self.value() {
    Err(e) => return Err(e)
    Ok(value) => value
  }
  let result = transform(value)
  if result.length() > 8192 {
    return Err(TooLong(8192))
  }
  match self.set_value(result) {
    Err(e) => Err(e)
    Ok(next) =>
      match next.value() {
        Err(e) => Err(e)
        Ok(_) => Ok(next)
      }
  }
}
