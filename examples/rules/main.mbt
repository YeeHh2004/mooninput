///|
/// All rule calculations and callbacks here run in MoonBit on both backends.
fn main {
  let choices = @input.dynamic([
    ("short", @input.pattern("##-##").unwrap()),
    ("long", @input.pattern("###-###").unwrap()),
  ]).unwrap()
  let dynamic = @input.Editor::new(choices, initial="123456").unwrap()
  println("dynamic=" + dynamic.active_mask().unwrap() + ":" + dynamic.display())
  let time = @input.composite([
    @input.Block("hour", @input.range(0, 23, width=2).unwrap()),
    @input.Literal(":"),
    @input.Block("minute", @input.range(0, 59, width=2).unwrap()),
  ]).unwrap()
  println("composite=" + @input.pipe(time, "2359").unwrap())
  let digit = @input.definition(
    'H',
    c => "0123456789abcdefABCDEF".contains_char(c),
    normalize=c => c.to_ascii_uppercase(),
  )
  let hex = @input.pattern("HH:HH", definitions=[digit]).unwrap()
  println("definition=" + @input.pipe(hex, "ab12").unwrap())
  let username = @input.regex("[A-Za-z][A-Za-z0-9_]{2,15}").unwrap()
  println("regex=" + @input.pipe(username, "moon_bit").unwrap())
  let repeated = @input.repeat(@input.enumeration(["ON", "OFF"]).unwrap(), 1, 3).unwrap()
  println("repeat=" + @input.pipe(repeated, "ONOFF").unwrap())
  let money = @input.number(
    radix=',',
    group_separator=".",
    max="9007199254740994.00",
  ).unwrap()
  println(
    "number=" +
    @input.pipe(money, "9.007.199.254.740.993,10", unmask=true).unwrap(),
  )
  let calendar = @input.date(
    format="DD/MM/YYYY",
    min="2020-01-01",
    max="2030-12-31",
  ).unwrap()
  println("date=" + @input.pipe(calendar, "29022024", unmask=true).unwrap())
  let checksum = @input.with_validation(@input.pattern("####").unwrap(), value => {
    if value.length() < 4 {
      return @input.Incomplete
    }
    let mut sum = 0
    for c in value {
      sum += c.to_int() - 48
    }
    if sum % 10 == 0 {
      @input.Complete
    } else {
      @input.Invalid("checksum must be divisible by ten")
    }
  })
  println("validation=" + @input.pipe(checksum, "1216", unmask=true).unwrap())
  let growing = @input.custom(
    value => {
      let chars = value.to_array()
      for i, c in chars {
        if !c.is_ascii_digit() || (i > 0 && c <= chars[i - 1]) {
          return @input.Invalid("digits must strictly increase")
        }
      }
      if chars.length() < 3 {
        @input.Incomplete
      } else {
        @input.Complete
      }
    },
    max_length=9,
  ).unwrap()
  println("function=" + @input.pipe(growing, "135", unmask=true).unwrap())
  let shown = @input.presentation(
    @input.pattern("##-##").unwrap(),
    placeholder='_',
    concealed='*',
  ).unwrap()
  println(
    "presentation=" + @input.Editor::new(shown, initial="12").unwrap().display(),
  )
}
