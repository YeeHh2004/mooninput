///|
/// Restore an immutable snapshot by revalidating both its editable and visible
/// representations. Formatted text may preserve otherwise ambiguous composite
/// block boundaries. Caller-provided raw/display pairs are never trusted alone.
pub fn Editor::restore(
  mask : Mask,
  raw : String,
  display : String,
  start : Int,
  end : Int,
) -> Result[Editor, InputError] {
  if raw.length() > 8192 || display.length() > 8192 {
    return Err(TooLong(8192))
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
