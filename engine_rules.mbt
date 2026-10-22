///|
/// An ordered composite consists of named editable blocks and fixed literals.
/// Optional blocks are skipped only when their input is absent.
pub(all) enum MaskPart {
  Literal(String)
  Block(String, Mask)
  Optional(String, Mask)
}

///|
fn rules_capacity(mask : Mask) -> Int? {
  match mask.kind {
    PatternKind(p) | DateKind(p) => Some(p.slots.length())
    DecimalKind(_, _, _) => Some(256)
    ExtensionKind(e) => e.capacity
  }
}

///|
fn rules_text(chars : Array[Char], start : Int, end : Int) -> String {
  let out : Array[Char] = []
  for i in start..<end {
    out.push(chars[i])
  }
  String::from_array(out)
}

///|
fn rules_fold(text : String) -> String {
  String::from_array(text.to_array().map(fn(c) { c.to_ascii_lowercase() }))
}

///|
fn rules_prefix(text : String, prefix : String) -> Bool {
  let a = text.to_array()
  let b = prefix.to_array()
  if b.length() > a.length() {
    return false
  }
  for i, c in b {
    if c != a[i] {
      return false
    }
  }
  true
}

///|
fn rules_padded(value : Int, width : Int) -> String {
  let mut text = value.to_string()
  while text.length() < width {
    text = "0" + text
  }
  text
}

///|
/// A non-negative, fixed-width integer range. Autofix clamps each impossible
/// prefix to the nearest viable prefix; no floating point conversion is used.
pub fn range(
  min : Int,
  max : Int,
  width? : Int = max.to_string().length(),
  autofix? : Bool = false,
) -> Result[Mask, InputError] {
  if min < 0 ||
    min > max ||
    max > 999999999 ||
    width < 1 ||
    width > 9 ||
    max.to_string().length() > width {
    return Err(
      InvalidConfig(
        "range requires 0 <= min <= max <= 999999999 and a sufficient width of 1..9",
      ),
    )
  }
  Ok(
    extension(
      fn(text) {
        if text.length() > width {
          return Err(TooLong(width))
        }
        if text == "" {
          return Ok(text_render("", Empty))
        }
        let mut number = 0
        for i, c in text.to_array() {
          if !c.is_ascii_digit() {
            return Err(InvalidCharacter(i, c.to_string()))
          }
          number = number * 10 + c.to_int() - '0'.to_int()
        }
        let mut factor = 1
        for _ in text.length()..<width {
          factor *= 10
        }
        let low = min / factor
        let high = max / factor
        if number < low || number > high {
          if !autofix {
            return Err(
              InvalidValue(
                "prefix cannot produce a value in the configured range",
              ),
            )
          }
          number = number.max(low).min(high)
        }
        let result = rules_padded(number, text.length())
        Ok(
          text_render(
            result,
            if text.length() == width {
              Complete
            } else {
              Incomplete
            },
            value=result,
          ),
        )
      },
      capacity=width,
    ),
  )
}

///|
/// Match a finite set of strings, accepting prefixes while the user is typing.
/// Case-insensitive matching folds ASCII and displays the configured spelling.
pub fn enumeration(
  values : Array[String],
  case_sensitive? : Bool = true,
) -> Result[Mask, InputError] {
  if values.is_empty() || values.length() > 64 {
    return Err(InvalidConfig("enumeration needs 1..64 values"))
  }
  let choices : Array[String] = []
  let keys : Array[String] = []
  let mut capacity = 0
  for value in values {
    if value == "" ||
      value.length() > 128 ||
      value.to_array().any(fn(c) { !c.is_printable() }) {
      return Err(
        InvalidConfig(
          "enumeration values must contain 1..128 printable UTF-16 units",
        ),
      )
    }
    let key = if case_sensitive { value } else { rules_fold(value) }
    if keys.contains(key) {
      return Err(
        InvalidConfig(
          "enumeration values must be distinct under the selected case policy",
        ),
      )
    }
    choices.push(value)
    keys.push(key)
    capacity = capacity.max(value.to_array().length())
  }
  Ok(
    extension(
      fn(text) {
        if text.length() > 128 {
          return Err(TooLong(128))
        }
        if text == "" {
          return Ok(text_render("", Empty))
        }
        let key = if case_sensitive { text } else { rules_fold(text) }
        let mut selected = -1
        for i, choice in keys {
          if choice == key {
            selected = i
            break
          }
          if selected == -1 && rules_prefix(choice, key) {
            selected = i
          }
        }
        if selected == -1 {
          return Err(
            InvalidValue("input is not a prefix of any enumeration value"),
          )
        }
        let full = choices[selected]
        let shown = rules_text(full.to_array(), 0, text.to_array().length())
        let state = if keys[selected] == key { Complete } else { Incomplete }
        Ok(text_render(shown, state, value=full))
      },
      capacity~,
    ),
  )
}

///|
fn rules_status_score(status : Status) -> Int {
  match status {
    Complete => 3
    Incomplete => 2
    Empty => 1
    Invalid(_) => 0
  }
}

///|
/// Select a fitting mask automatically, preferring complete then narrower
/// candidates. A dispatch callback may name a candidate or return None to use
/// automatic selection. Candidate names are surfaced by Editor::active_mask.
pub fn dynamic(
  candidates : Array[(String, Mask)],
  dispatch? : (String) -> String?,
) -> Result[Mask, InputError] {
  if candidates.is_empty() || candidates.length() > 64 {
    return Err(InvalidConfig("dynamic masks need 1..64 candidates"))
  }
  let choices : Array[(String, Mask)] = []
  let names : Array[String] = []
  let mut capacity = 0
  for (name, mask) in candidates {
    if name == "" || name.length() > 128 || names.contains(name) {
      return Err(
        InvalidConfig("dynamic candidate names must be nonempty and distinct"),
      )
    }
    names.push(name)
    choices.push((name, mask))
    capacity = capacity.max(rules_capacity(mask).unwrap_or(8192))
  }
  Ok(
    extension(
      fn(text) {
        if text.length() > 8192 {
          return Err(TooLong(8192))
        }
        let dispatched = match dispatch {
          Some(f) => f(text)
          None => None
        }
        match dispatched {
          Some(name) => {
            for (candidate_name, mask) in choices {
              if name == candidate_name {
                return match mask.render_input(text) {
                  Err(e) => Err(e)
                  Ok(render) =>
                    Ok({ ..enrich_render(render, mask), active: Some(name), })
                }
              }
            }
            return Err(
              InvalidValue("dispatch selected an unknown dynamic candidate"),
            )
          }
          None => ()
        }
        let mut best : Render? = None
        let mut best_score = -1
        let mut best_capacity = 8193
        for (name, mask) in choices {
          match mask.render_input(text) {
            Err(_) => ()
            Ok(render) => {
              let render = enrich_render(render, mask)
              let score = rules_status_score(render.state.unwrap_or(Incomplete))
              let cap = rules_capacity(mask).unwrap_or(8192)
              if score > best_score ||
                (score == best_score && cap < best_capacity) {
                best = Some({ ..render, active: Some(name), })
                best_score = score
                best_capacity = cap
              }
            }
          }
        }
        match best {
          Some(render) => Ok(render)
          None => Err(InvalidValue("input does not fit any dynamic candidate"))
        }
      },
      capacity~,
    ),
  )
}

///|
/// A user-defined mask returns Empty/Incomplete/Complete/Invalid for each
/// prefix. Preparation is applied before validation. Exceptions in user code
/// are not caught; callbacks must be deterministic and side-effect free.
pub fn custom(
  validate : (String) -> Status,
  max_length? : Int = 256,
  prepare? : (String) -> String,
) -> Result[Mask, InputError] {
  if max_length < 1 || max_length > 8192 {
    return Err(InvalidConfig("custom maximum length must be 1..8192"))
  }
  Ok(
    extension(
      fn(text) {
        if text.length() > 8192 {
          return Err(TooLong(8192))
        }
        let value = match prepare {
          Some(f) => f(text)
          None => text
        }
        if value.length() > max_length {
          return Err(TooLong(max_length))
        }
        if value.to_array().any(fn(c) { !c.is_printable() }) {
          return Err(InvalidValue("custom input contains control characters"))
        }
        let state = if value == "" { Empty } else { validate(value) }
        Ok(text_render(value, state, value~))
      },
      capacity=max_length,
    ),
  )
}

///|
/// Add semantic validation to a base mask. Syntax errors still reject an edit;
/// Invalid results remain editable, with value() returning an error.
pub fn with_validation(mask : Mask, validate : (String) -> Status) -> Mask {
  extension(
    fn(text) {
      match mask.render_input(text) {
        Err(e) => Err(e)
        Ok(render) => {
          let render = enrich_render(render, mask)
          if render.raw.is_empty() {
            return Ok(render)
          }
          let checked = validate(String::from_array(render.raw))
          let state = match (render.state, checked) {
            (Some(Invalid(reason)), _) => Some(Invalid(reason))
            (_, Complete) => render.state
            _ => Some(checked)
          }
          Ok({ ..render, state, })
        }
      }
    },
    capacity=rules_capacity(mask).unwrap_or(8192),
    fragment?=mask.fragment_normalizer(),
  )
}

///|
/// Normalize incoming text before the base mask parses it. The normalizer
/// receives the whole proposed value, including edits and programmatic sets.
/// Preparation deliberately does not inherit fragment parsing: the callback
/// must be able to normalize incoming text before the base mask validates it.
pub fn with_prepare(mask : Mask, prepare : (String) -> String) -> Mask {
  extension(
    fn(text) {
      if text.length() > 8192 {
        return Err(TooLong(8192))
      }
      let prepared = prepare(text)
      if prepared.length() > 8192 {
        return Err(TooLong(8192))
      }
      match mask.render_input(prepared) {
        Err(e) => Err(e)
        Ok(render) => Ok(enrich_render(render, mask))
      }
    },
    capacity=rules_capacity(mask).unwrap_or(8192),
  )
}

///|
priv struct RulesBudget {
  mut remaining : Int
}

///|
priv struct RulesPiece {
  render : Render
  complete : Bool
}

///|
fn rules_join(head : Render, tail : Render) -> Render {
  let raw = head.raw.copy()
  let starts = head.starts.copy()
  let ends = head.ends.copy()
  let fields = head.fields.copy()
  for c in tail.raw {
    raw.push(c)
  }
  for start in tail.starts {
    starts.push(head.display.length() + start)
  }
  for end in tail.ends {
    ends.push(head.display.length() + end)
  }
  for field in tail.fields {
    fields.push(field)
  }
  let display = head.display + tail.display
  let canonical = head.canonical.unwrap_or(String::from_array(head.raw)) +
    tail.canonical.unwrap_or(String::from_array(tail.raw))
  let state = match (head.state, tail.state) {
    (Some(Invalid(reason)), _) | (_, Some(Invalid(reason))) => Invalid(reason)
    _ => Incomplete
  }
  {
    raw,
    display,
    starts,
    ends,
    state: Some(state),
    canonical: Some(canonical),
    active: None,
    fields,
    reconcile_by_edit: head.reconcile_by_edit || tail.reconcile_by_edit,
  }
}

///|
fn rules_composite_walk(
  parts : Array[MaskPart],
  chars : Array[Char],
  part : Int,
  input : Int,
  formatted : Bool,
  budget : RulesBudget,
) -> Result[RulesPiece?, InputError] {
  budget.remaining -= 1
  if budget.remaining < 0 {
    return Err(
      InvalidValue("composite parsing exceeded its bounded search budget"),
    )
  }
  if part == parts.length() {
    return Ok(
      if input == chars.length() {
        Some({ render: text_render("", Empty), complete: true, })
      } else {
        None
      },
    )
  }
  match parts[part] {
    Literal(literal) => {
      let units = literal.to_array()
      let mut next = input
      if formatted && input < chars.length() {
        if !matches_at(chars, input, units) {
          return Ok(None)
        }
        next += units.length()
      }
      match
        rules_composite_walk(parts, chars, part + 1, next, formatted, budget) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some(tail)) =>
          if tail.render.raw.is_empty() &&
            tail.render.display == "" &&
            part != parts.length() - 1 {
            Ok(Some(tail))
          } else {
            let prefix = {
              ..text_render("", Empty),
              display: literal,
              canonical: Some(literal),
            }
            let joined = rules_join(prefix, tail.render)
            let state = if joined.raw.is_empty() {
              Empty
            } else {
              match tail.render.state {
                Some(Invalid(reason)) => Invalid(reason)
                _ => if tail.complete { Complete } else { Incomplete }
              }
            }
            Ok(
              Some({
                render: { ..joined, state: Some(state), },
                complete: tail.complete,
              }),
            )
          }
      }
    }
    Block(name, mask) | Optional(name, mask) => {
      let optional = match parts[part] {
        Optional(_, _) => true
        _ => false
      }
      let max_end = chars.length()
      let mut end = max_end
      let mut fallback : RulesPiece? = None
      while end >= input {
        budget.remaining -= 1
        if budget.remaining < 0 {
          if fallback is Some(_) {
            return Ok(fallback)
          }
          return Err(
            InvalidValue("composite parsing exceeded its bounded search budget"),
          )
        }
        let chunk = rules_text(chars, input, end)
        match mask.render_input(chunk) {
          Err(_) => ()
          Ok(render) => {
            let child = enrich_render(render, mask)
            let child_complete = match child.state {
              Some(Complete) => true
              _ => false
            }
            let child_invalid = match child.state {
              Some(Invalid(_)) => true
              _ => false
            }
            // Semantic validation failures still occupy a syntactically parsed
            // block, so dates/bounded numbers can be repaired beside other data.
            if end == chars.length() ||
              child_complete ||
              child_invalid ||
              (optional && end == input) {
              match
                rules_composite_walk(
                  parts,
                  chars,
                  part + 1,
                  end,
                  formatted,
                  budget,
                ) {
                Err(e) => {
                  // A fully consumed syntactic partition is still an editable
                  // result when its values are semantically invalid. Do not
                  // discard it merely because searching for a better partition
                  // exhausted the shared budget.
                  if budget.remaining < 0 && fallback is Some(_) {
                    return Ok(fallback)
                  }
                  return Err(e)
                }
                Ok(None) => ()
                Ok(Some(tail)) => {
                  let fields : Array[FieldValue] = []
                  if !child.raw.is_empty() {
                    fields.push({
                      name,
                      value: child.canonical.unwrap_or(
                        String::from_array(child.raw),
                      ),
                    })
                    for field in child.fields {
                      fields.push({
                        name: name + "." + field.name,
                        value: field.value,
                      })
                    }
                  }
                  let head = { ..child, fields, }
                  let satisfied = child_complete ||
                    (optional && child.raw.is_empty())
                  // A suffix becomes visible only when preceding blocks are
                  // complete, including absent optional children.
                  let tail_render = if !satisfied && tail.render.raw.is_empty() {
                    { ..tail.render, display: "", canonical: Some(""), }
                  } else {
                    tail.render
                  }
                  let render = rules_join(head, tail_render)
                  let complete = satisfied && tail.complete
                  let state = if render.raw.is_empty() {
                    Empty
                  } else {
                    match render.state {
                      Some(Invalid(reason)) => Invalid(reason)
                      _ => if complete { Complete } else { Incomplete }
                    }
                  }
                  let piece = {
                    render: { ..render, state: Some(state), },
                    complete,
                  }
                  if complete {
                    return Ok(Some(piece))
                  }
                  match fallback {
                    None => fallback = Some(piece)
                    Some(previous) =>
                      if rules_status_score(
                          piece.render.state.unwrap_or(Incomplete),
                        ) >
                        rules_status_score(
                          previous.render.state.unwrap_or(Incomplete),
                        ) {
                        fallback = Some(piece)
                      }
                  }
                }
              }
            }
          }
        }
        end -= 1
      }
      Ok(fallback)
    }
  }
}

///|
/// Compose nested masks with named fields, fixed literals and optional blocks.
/// Raw input is tried first; formatted input is a fallback. Ambiguous variable
/// blocks use longest fitting complete prefixes. Parsing is bounded to 2048
/// UTF-16 units, 64 parts and 16384 search steps per pass.
pub fn composite(parts : Array[MaskPart]) -> Result[Mask, InputError] {
  if parts.is_empty() || parts.length() > 64 {
    return Err(InvalidConfig("composite masks need 1..64 parts"))
  }
  let rules : Array[MaskPart] = []
  let names : Array[String] = []
  let mut capacity = 0
  let mut literal_length = 0
  for part in parts {
    match part {
      Literal(text) => {
        if text == "" ||
          text.length() > 256 ||
          text.to_array().any(fn(c) { !c.is_printable() }) {
          return Err(
            InvalidConfig(
              "composite literals must contain 1..256 printable UTF-16 units",
            ),
          )
        }
        literal_length += text.length()
      }
      Block(name, mask) | Optional(name, mask) => {
        if name == "" || name.length() > 128 || names.contains(name) {
          return Err(
            InvalidConfig("composite block names must be nonempty and distinct"),
          )
        }
        names.push(name)
        capacity += rules_capacity(mask).unwrap_or(8192)
        if capacity > 2048 {
          return Err(
            InvalidConfig(
              "composite total editable capacity must not exceed 2048",
            ),
          )
        }
      }
    }
    rules.push(part)
  }
  if names.is_empty() {
    return Err(
      InvalidConfig("composite masks require at least one editable block"),
    )
  }
  if literal_length + capacity > 2048 {
    return Err(
      InvalidConfig(
        "composite total capacity including literals must not exceed 2048",
      ),
    )
  }
  Ok(
    extension(
      fn(text) {
        if text.length() > 2048 {
          return Err(TooLong(2048))
        }
        let chars = text.to_array()
        for formatted in [false, true] {
          match
            rules_composite_walk(rules, chars, 0, 0, formatted, {
              remaining: 16384,
            }) {
            Err(e) => return Err(e)
            Ok(Some(piece)) => {
              if piece.render.display.length() > 2048 {
                return Err(TooLong(2048))
              }
              if piece.render.canonical.unwrap_or("").length() > 8192 {
                return Err(TooLong(8192))
              }
              return Ok(piece.render)
            }
            Ok(None) => ()
          }
        }
        Err(InvalidValue("input does not fit the composite blocks"))
      },
      capacity~,
    ),
  )
}

///|
/// Repeat an arbitrary child mask. Each completed repetition is a numbered
/// field. Bounds are finite (0 <= min <= max <= 32); incomplete final children
/// remain editable and never count as completed repetitions.
pub fn repeat(mask : Mask, min : Int, max : Int) -> Result[Mask, InputError] {
  if min < 0 || min > max || max < 1 || max > 32 {
    return Err(
      InvalidConfig("repeat requires 0 <= min <= max <= 32 and max >= 1"),
    )
  }
  if rules_capacity(mask).unwrap_or(8192) < 1 {
    return Err(InvalidConfig("repeated masks must accept nonempty input"))
  }
  let parts : Array[MaskPart] = []
  for i in 0..<max {
    let name = i.to_string()
    parts.push(if i < min { Block(name, mask) } else { Optional(name, mask) })
  }
  composite(parts)
}
