///|
priv struct Config {
  kind : String
  pattern : String?
  precision : Int?
  signed : Bool?
  grouped : Bool?
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
fn configure(config : Config) -> Result[@input.Mask, @input.InputError] {
  match config.kind {
    "pattern" =>
      match config.pattern {
        Some(source) => @input.pattern(source)
        None => Err(@input.InvalidConfig("pattern is required"))
      }
    "decimal" =>
      @input.decimal(
        precision=config.precision.unwrap_or(2),
        signed=config.signed.unwrap_or(false),
        grouped=config.grouped.unwrap_or(true),
      )
    "date" => Ok(@input.iso_date())
    _ => Err(@input.InvalidConfig("unknown mask kind"))
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
    _ =>
      match selected {
        Err(e) => Err(e)
        Ok(current) =>
          match request.op {
            "select" => Ok(current)
            "insert" => current.insert(request.text)
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
