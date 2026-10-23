///|
/// Restore an immutable snapshot by revalidating both its editable and visible
/// representations. Formatted text may preserve otherwise ambiguous composite
/// block boundaries. Caller-provided raw/display pairs are never trusted alone.
/// If supplied, replay must reproduce both representations exactly; a corrupt
/// replay is rejected instead of falling back to another interpretation.
pub fn Editor::restore(
  mask : Mask,
  raw : String,
  display : String,
  start : Int,
  end : Int,
  replay? : String,
) -> Result[Editor, InputError] {
  if raw.length() > 8192 || display.length() > 8192 {
    return Err(TooLong(8192))
  }
  if replay is Some(text) {
    if text.length() > 8192 {
      return Err(TooLong(8192))
    }
    return match Editor::new(mask, initial=text) {
      Ok(candidate) =>
        if candidate.raw() == raw && candidate.display() == display {
          candidate.select(start, end)
        } else {
          Err(
            InvalidValue("snapshot replay does not match the configured rule"),
          )
        }
      Err(error) => Err(error)
    }
  }
  match Editor::new(mask, initial=raw) {
    Ok(candidate) =>
      if candidate.raw() == raw && candidate.display() == display {
        return candidate.select(start, end)
      }
    Err(_) => ()
  }
  match Editor::new(mask, initial=display) {
    Ok(candidate) =>
      if candidate.raw() == raw && candidate.display() == display {
        return candidate.select(start, end)
      }
    Err(_) => ()
  }
  Err(InvalidValue("snapshot does not match the configured rule"))
}
