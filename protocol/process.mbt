///|
priv struct Config {
  kind : String
  pattern : String?
  precision : Int?
  signed : Bool?
  grouped : Bool?
  definitions : Array[TokenConfig]?
  source : String?
  caseInsensitive : Bool?
  from : Int?
  to : Int?
  width : Int?
  autofix : Bool?
  values : Array[String]?
  caseSensitive : Bool?
  masks : Array[Config]?
  name : String?
  startsWith : String?
  parts : Array[Config]?
  literal : String?
  rule : Config?
  minRepeat : Int?
  maxRepeat : Int?
  radix : String?
  groupSeparator : String?
  mapRadix : String?
  min : String?
  max : String?
  padFraction : Bool?
  normalizeZeros : Bool?
  format : String?
  allowed : String?
  equals : String?
  minLength : Int?
  maxLength : Int?
  placeholder : String?
  concealed : String?
  eager : Bool?
  prepare : String?
  commit : String?
  overwrite : Bool?
  skipInvalid : Bool?
} derive(@json.FromJson)

///|
priv struct TokenConfig {
  token : String
  characters : String
  uppercase : Bool?
} derive(@json.FromJson)

///|
priv struct Request {
  config : Config
  value : String
  op : String
  start : Int
  end : Int
  text : String
} derive(@json.FromJson)

///|
fn scalar(text : String) -> Result[Char, @input.InputError] {
  let chars = text.to_array()
  if chars.length() != 1 {
    Err(@input.InvalidConfig("option requires one Unicode scalar"))
  } else {
    Ok(chars[0])
  }
}

///|
fn transform(text : String, mode : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  if mode == "trim" {
    fn space(c : Char) -> Bool {
      c == ' ' || c == '\t' || c == '\r' || c == '\n'
    }
    while start < end && space(chars[start]) {
      start += 1
    }
    while end > start && space(chars[end - 1]) {
      end -= 1
    }
  }
  let result : Array[Char] = []
  for i in start..<end {
    result.push(
      if mode == "uppercase" {
        chars[i].to_ascii_uppercase()
      } else if mode == "lowercase" {
        chars[i].to_ascii_lowercase()
      } else {
        chars[i]
      },
    )
  }
  String::from_array(result)
}

///|
fn configure(
  config : Config,
  depth? : Int = 0,
) -> Result[@input.Mask, @input.InputError] {
  if depth > 16 {
    return Err(@input.InvalidConfig("rule nesting exceeds 16"))
  }
  if config.commit is Some(mode) {
    if mode != "identity" &&
      mode != "uppercase" &&
      mode != "lowercase" &&
      mode != "trim" {
      return Err(@input.InvalidConfig("unknown commit mode"))
    }
  }
  let mask = match config.kind {
    "pattern" =>
      match config.pattern {
        Some(source) => {
          let definitions : Array[@input.Definition] = []
          for token in config.definitions.unwrap_or([]) {
            let character = match scalar(token.token) {
              Ok(c) => c
              Err(e) => return Err(e)
            }
            if token.characters.length() > 4096 {
              return Err(
                @input.InvalidConfig("definition character set exceeds limit"),
              )
            }
            definitions.push(
              @input.definition(
                character,
                c => token.characters.contains_char(c),
                normalize=c => {
                  if token.uppercase.unwrap_or(false) {
                    c.to_ascii_uppercase()
                  } else {
                    c
                  }
                },
              ),
            )
          }
          @input.pattern(source, definitions~)
        }
        None => Err(@input.InvalidConfig("pattern is required"))
      }
    "decimal" =>
      @input.decimal(
        precision=config.precision.unwrap_or(2),
        signed=config.signed.unwrap_or(false),
        grouped=config.grouped.unwrap_or(true),
      )
    "date" =>
      @input.date(
        format=config.format.unwrap_or("YYYY-MM-DD"),
        min=config.min.unwrap_or("0001-01-01"),
        max=config.max.unwrap_or("9999-12-31"),
      )
    "number" => {
      let radix = match scalar(config.radix.unwrap_or(".")) {
        Ok(c) => c
        Err(e) => return Err(e)
      }
      @input.number(
        precision=config.precision.unwrap_or(2),
        signed=config.signed.unwrap_or(true),
        radix~,
        group_separator=config.groupSeparator.unwrap_or(","),
        map_radix=config.mapRadix.unwrap_or(""),
        min=config.min.unwrap_or(""),
        max=config.max.unwrap_or(""),
        pad_fraction=config.padFraction.unwrap_or(false),
        normalize_zeros=config.normalizeZeros.unwrap_or(false),
        autofix=config.autofix.unwrap_or(false),
      )
    }
    "regex" =>
      @input.regex(
        config.source.unwrap_or(""),
        case_insensitive=config.caseInsensitive.unwrap_or(false),
        max_length=config.maxLength.unwrap_or(8192),
      )
    "range" =>
      @input.range(
        config.from.unwrap_or(0),
        config.to.unwrap_or(99),
        width=config.width.unwrap_or(2),
        autofix=config.autofix.unwrap_or(false),
      )
    "enum" =>
      @input.enumeration(
        config.values.unwrap_or([]),
        case_sensitive=config.caseSensitive.unwrap_or(true),
      )
    "dynamic" => {
      let configs = config.masks.unwrap_or([])
      if configs.length() > 64 {
        return Err(@input.InvalidConfig("at most 64 dynamic masks"))
      }
      let masks : Array[(String, @input.Mask)] = []
      let mut has_prefix = false
      for i, child in configs {
        let next = match configure(child, depth=depth + 1) {
          Ok(m) => m
          Err(e) => return Err(e)
        }
        masks.push((child.name.unwrap_or(i.to_string()), next))
        if child.startsWith is Some(_) {
          has_prefix = true
        }
      }
      if has_prefix {
        @input.dynamic(masks, dispatch=text => {
          let mut found : String? = None
          let mut score = -1
          for i, child in configs {
            let prefix = child.startsWith.unwrap_or("")
            if (text.has_prefix(prefix) || prefix.has_prefix(text)) &&
              prefix.length() > score {
              found = Some(child.name.unwrap_or(i.to_string()))
              score = prefix.length()
            }
          }
          found
        })
      } else {
        @input.dynamic(masks)
      }
    }
    "composite" => {
      let parts : Array[@input.MaskPart] = []
      let configured = config.parts.unwrap_or([])
      if configured.length() > 64 {
        return Err(@input.InvalidConfig("at most 64 composite parts"))
      }
      for child in configured {
        if child.kind == "literal" {
          parts.push(@input.Literal(child.literal.unwrap_or("")))
        } else {
          let rule = match child.rule {
            Some(r) => r
            None => return Err(@input.InvalidConfig("block rule is required"))
          }
          let next = match configure(rule, depth=depth + 1) {
            Ok(m) => m
            Err(e) => return Err(e)
          }
          let name = child.name.unwrap_or("")
          if child.kind == "optional" {
            parts.push(@input.Optional(name, next))
          } else if child.kind == "block" {
            parts.push(@input.Block(name, next))
          } else {
            return Err(@input.InvalidConfig("unknown composite part"))
          }
        }
      }
      @input.composite(parts)
    }
    "repeat" => {
      let child = match config.rule {
        Some(r) => r
        None => return Err(@input.InvalidConfig("repeat rule is required"))
      }
      let rule = match configure(child, depth=depth + 1) {
        Ok(m) => m
        Err(e) => return Err(e)
      }
      @input.repeat(
        rule,
        config.minRepeat.unwrap_or(1),
        config.maxRepeat.unwrap_or(8),
      )
    }
    "validate" => {
      let child = match config.rule {
        Some(r) => r
        None => return Err(@input.InvalidConfig("validation rule is required"))
      }
      let rule = match configure(child, depth=depth + 1) {
        Ok(m) => m
        Err(e) => return Err(e)
      }
      let low = config.minLength.unwrap_or(0)
      let high = config.maxLength.unwrap_or(8192)
      if low < 0 || high < low || high > 8192 {
        return Err(@input.InvalidConfig("invalid validation length interval"))
      }
      Ok(
        @input.with_validation(rule, value => {
          if value.length() < low {
            return @input.Incomplete
          }
          if value.length() > high {
            return @input.Invalid("value exceeds maximum length")
          }
          if config.allowed is Some(allowed) {
            for c in value {
              if !allowed.contains_char(c) {
                return @input.Invalid("character is outside allowed set")
              }
            }
          }
          if config.startsWith is Some(prefix) {
            if prefix.has_prefix(value) && value != prefix {
              return @input.Incomplete
            }
            if !value.has_prefix(prefix) {
              return @input.Invalid("value does not have required prefix")
            }
          }
          if config.equals is Some(expected) {
            if value != expected {
              return @input.Invalid("value does not match required text")
            }
          }
          @input.Complete
        }),
      )
    }
    "presentation" => {
      let child = match config.rule {
        Some(r) => r
        None =>
          return Err(@input.InvalidConfig("presentation rule is required"))
      }
      let rule = match configure(child, depth=depth + 1) {
        Ok(m) => m
        Err(e) => return Err(e)
      }
      let placeholder = match scalar(config.placeholder.unwrap_or("_")) {
        Ok(c) => c
        Err(e) => return Err(e)
      }
      if config.concealed is Some(text) {
        let concealed = match scalar(text) {
          Ok(c) => c
          Err(e) => return Err(e)
        }
        @input.presentation(
          rule,
          placeholder~,
          concealed~,
          eager=config.eager.unwrap_or(false),
        )
      } else {
        @input.presentation(
          rule,
          placeholder~,
          eager=config.eager.unwrap_or(false),
        )
      }
    }
    _ => Err(@input.InvalidConfig("unknown mask kind"))
  }
  match mask {
    Err(e) => Err(e)
    Ok(mask) =>
      match config.prepare {
        Some(mode) =>
          if mode == "uppercase" || mode == "lowercase" || mode == "trim" {
            Ok(@input.with_prepare(mask, text => transform(text, mode)))
          } else {
            Err(@input.InvalidConfig("unknown preparation mode"))
          }
        None => Ok(mask)
      }
  }
}

///|
fn code(error : @input.InputError) -> String {
  match error {
    @input.InvalidPattern(_) => "pattern"
    @input.InvalidCharacter(_, _) => "character"
    @input.TooLong(_) => "length"
    @input.InvalidSelection => "selection"
    @input.InvalidConfig(_) => "config"
    @input.InvalidValue(_) => "value"
  }
}

///|
fn snapshot(editor : @input.Editor) -> Json {
  let (status, reason) = match editor.status() {
    @input.Empty => ("empty", "")
    @input.Incomplete => ("incomplete", "")
    @input.Complete => ("complete", "")
    @input.Invalid(reason) => ("invalid", reason)
  }
  let value : Json = match editor.value() {
    Ok(value) => value.to_json()
    Err(_) => Json::null()
  }
  {
    "raw": editor.raw(),
    "display": editor.display(),
    "start": editor.selection().start,
    "end": editor.selection().end,
    "status": status,
    "reason": reason,
    "value": value,
    "active": match editor.active_mask() {
      Some(name) => name.to_json()
      None => Json::null()
    },
    "fields": editor
    .fields()
    .map(field => ({ "name": field.name, "value": field.value } : Json)),
  }
}

///|
fn failure(error : @input.InputError) -> Json {
  { "ok": false, "code": code(error), "error": error.message() }
}

///|
/// Stateless, bounded JSON boundary used by the browser and CLI. Required
/// request fields: config, value, op, start, end, text. Value is previous raw text.
pub fn process(text : String) -> String {
  if text.length() > 65536 {
    return failure(@input.TooLong(65536)).stringify()
  }
  let mut depth = 0
  let mut quoted = false
  let mut escaped = false
  for c in text {
    if quoted {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        quoted = false
      }
    } else if c == '"' {
      quoted = true
    } else if c == '{' || c == '[' {
      depth += 1
      if depth > 48 {
        return failure(@input.InvalidConfig("JSON nesting exceeds limit")).stringify()
      }
    } else if c == '}' || c == ']' {
      depth -= 1
    }
  }
  let request : Request = @json.from_json(@json.parse(text)) catch {
    _ =>
      return failure(@input.InvalidConfig("invalid JSON request schema")).stringify()
  }
  let mask = match configure(request.config) {
    Ok(mask) => mask
    Err(e) => return failure(e).stringify()
  }
  let editor = match @input.Editor::new(mask, initial=request.value) {
    Ok(editor) => editor
    Err(e) => return failure(e).stringify()
  }
  let selected = editor.select(request.start, request.end)
  let result = match request.op {
    "init" => Ok(editor)
    "set" => editor.set_value(request.text)
    "reconcile" => editor.reconcile(request.text, request.start, request.end)
    "commit" => {
      let mode = request.config.commit.unwrap_or("identity")
      if editor.status() != @input.Complete {
        Err(
          @input.InvalidValue("incomplete or invalid input cannot be committed"),
        )
      } else if request.config.kind == "number" {
        match editor.value() {
          Err(e) => Err(e)
          Ok(value) => {
            let radix = request.config.radix.unwrap_or(".")
            let mut localized = ""
            for c in transform(value, mode) {
              localized += if c == '.' { radix } else { c.to_string() }
            }
            editor.set_value(localized)
          }
        }
      } else if mode == "identity" || request.config.kind == "date" {
        Ok(editor)
      } else if mode == "uppercase" || mode == "lowercase" || mode == "trim" {
        editor.commit(text => transform(text, mode))
      } else {
        Err(@input.InvalidConfig("unknown commit mode"))
      }
    }
    _ =>
      match selected {
        Err(e) => Err(e)
        Ok(current) =>
          match request.op {
            "select" => Ok(current)
            "insert" =>
              current.insert(
                request.text,
                overwrite=request.config.overwrite.unwrap_or(false),
                skip_invalid=request.config.skipInvalid.unwrap_or(false),
              )
            "backspace" => current.backspace()
            "delete" => current.delete_forward()
            _ => Err(@input.InvalidConfig("unknown operation"))
          }
      }
  }
  let response : Json = match result {
    Ok(next) => { "ok": true, "state": snapshot(next) }
    Err(error) =>
      {
        "ok": false,
        "code": code(error),
        "error": error.message(),
        "state": snapshot(
          match selected {
            Ok(s) => s
            Err(_) => editor
          },
        ),
      }
  }
  response.stringify()
}
