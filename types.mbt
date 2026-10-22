///|
/// Errors never modify an existing editor.
pub(all) enum InputError {
  InvalidPattern(String)
  InvalidCharacter(Int, String)
  TooLong(Int)
  InvalidSelection
  InvalidConfig(String)
  InvalidValue(String)
} derive(Eq, @debug.Debug)

///|
/// Positions use UTF-16 offsets, including on Wasm GC.
pub(all) struct Selection {
  start : Int
  end : Int
} derive(Eq, @debug.Debug)

///|
pub(all) enum Status {
  Empty
  Incomplete
  Complete
  Invalid(String)
} derive(Eq, @debug.Debug)

///|
priv enum Slot {
  Digit
  Letter
  Alnum
  Printable
  Custom((Char) -> Char?)
}

///|
priv struct Pattern {
  slots : Array[Slot]
  prefixes : Array[String]
  required : Int
}

///|
priv enum Kind {
  PatternKind(Pattern)
  DateKind(Pattern)
  DecimalKind(Int, Bool, Bool)
  ExtensionKind(Extension)
}

///|
priv struct Extension {
  parse : (String) -> Result[Render, InputError]
  capacity : Int?
  fragment : ((String) -> Result[Array[Char], InputError])?
}

///|
/// A named canonical value produced by a composite mask.
pub(all) struct FieldValue {
  name : String
  value : String
} derive(Eq, @debug.Debug)

///|
pub struct Definition {
  priv token : Char
  priv accept : (Char) -> Bool
  priv normalize : (Char) -> Char
}

///|
/// A compiled immutable input specification.
pub struct Mask {
  priv kind : Kind
}

///|
priv struct Render {
  raw : Array[Char]
  display : String
  starts : Array[Int]
  ends : Array[Int]
  state : Status?
  canonical : String?
  active : String?
  fields : Array[FieldValue]
  reconcile_by_edit : Bool
}

///|
/// An immutable snapshot; edits return a new editor or an error.
pub struct Editor {
  priv mask : Mask
  priv render : Render
  priv selection : Selection
}

///|
fn Slot::accept(self : Slot, c : Char) -> Char? {
  match self {
    Digit => if c.is_ascii_digit() { Some(c) } else { None }
    Letter =>
      if c.is_ascii_alphabetic() {
        Some(c.to_ascii_uppercase())
      } else {
        None
      }
    Alnum =>
      if c.is_ascii_alphabetic() || c.is_ascii_digit() {
        Some(c.to_ascii_uppercase())
      } else {
        None
      }
    Printable => if c.is_printable() { Some(c) } else { None }
    Custom(accept) => accept(c)
  }
}

///|
pub extend InputError with @debug.Debug::{to_repr}

///|
pub extend Selection with @debug.Debug::{to_repr}

///|
pub extend Status with @debug.Debug::{to_repr}

///|
pub extend InputError with Eq::{equal, not_equal}

///|
pub extend Selection with Eq::{equal, not_equal}

///|
pub extend Status with Eq::{equal, not_equal}

///|
pub extend FieldValue with Eq::{equal, not_equal}

///|
pub extend FieldValue with @debug.Debug::{to_repr}
