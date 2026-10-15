///|
// This regular-expression subset is implemented in MoonBit on Unicode scalars.
// Compilation uses Thompson's construction; editing simulates a set of NFA
// states, so nested alternatives and repetitions do not cause backtracking.
priv enum RegexSyntax {
  RegexEmpty
  RegexAtom(Array[(Int, Int)])
  RegexSequence(Array[RegexSyntax])
  RegexChoice(Array[RegexSyntax])
  RegexRepeat(RegexSyntax, Int, Int?)
}

///|
priv struct RegexParser {
  chars : Array[Char]
  limit : Int
  case_insensitive : Bool
  mut cursor : Int
  mut depth : Int
  mut error : String?
}

///|
priv struct RegexUnit {
  ranges : Array[(Int, Int)]
  literal : Int?
}

///|
priv enum RegexInstruction {
  RegexAccept
  RegexConsume(Array[(Int, Int)], Int)
  RegexFork(Int, Int)
}

///|
priv struct RegexCompiler {
  states : Array[RegexInstruction]
  mut exceeded : Bool
}

///|
fn regex_ranges_normalize(source : Array[(Int, Int)]) -> Array[(Int, Int)] {
  let sorted = source.copy()
  sorted.mut_view().sort_by((a, b) => a.0.compare(b.0))
  let result : Array[(Int, Int)] = []
  for range in sorted {
    if result.is_empty() {
      result.push(range)
    } else {
      let last = result[result.length() - 1]
      if range.0 <= last.1 + 1 {
        result[result.length() - 1] = (last.0, last.1.max(range.1))
      } else {
        result.push(range)
      }
    }
  }
  result
}

///|
fn regex_ranges_complement(source : Array[(Int, Int)]) -> Array[(Int, Int)] {
  let sorted = regex_ranges_normalize(source)
  let result : Array[(Int, Int)] = []
  // Unicode scalar values exclude the surrogate code points on both targets.
  for universe in [(0, 0xD7FF), (0xE000, 0x10FFFF)] {
    let mut cursor = universe.0
    for range in sorted {
      if range.1 >= cursor && range.0 <= universe.1 {
        if range.0 > cursor {
          result.push((cursor, (range.0 - 1).min(universe.1)))
        }
        cursor = cursor.max(range.1 + 1)
      }
    }
    if cursor <= universe.1 {
      result.push((cursor, universe.1))
    }
  }
  result
}

///|
fn RegexParser::fail(self : RegexParser, message : String) -> Unit {
  if self.error is None {
    self.error = Some("\{message} at scalar \{self.cursor}")
  }
}

///|
fn RegexParser::fold_ranges(
  self : RegexParser,
  source : Array[(Int, Int)],
) -> Array[(Int, Int)] {
  let ranges = source.copy()
  if self.case_insensitive {
    for range in source {
      let upper_start = range.0.max(65)
      let upper_end = range.1.min(90)
      if upper_start <= upper_end {
        ranges.push((upper_start + 32, upper_end + 32))
      }
      let lower_start = range.0.max(97)
      let lower_end = range.1.min(122)
      if lower_start <= lower_end {
        ranges.push((lower_start - 32, lower_end - 32))
      }
    }
  }
  regex_ranges_normalize(ranges)
}

///|
fn regex_literal(code : Int) -> RegexUnit {
  { ranges: [(code, code)], literal: Some(code), }
}

///|
fn RegexParser::hex_escape(self : RegexParser, count : Int) -> RegexUnit {
  let mut value = 0
  let mut digits = 0
  let braced = count == 4 &&
    self.cursor < self.limit &&
    self.chars[self.cursor] == '{'
  if braced {
    self.cursor += 1
  }
  while self.cursor < self.limit &&
        (if braced { self.chars[self.cursor] != '}' } else { digits < count }) {
    let c = self.chars[self.cursor]
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      self.fail("invalid hexadecimal escape")
      return regex_literal(0)
    }
    digits += 1
    if digits > 6 {
      self.fail("Unicode escape is too long")
      return regex_literal(0)
    }
    value = value * 16 + digit
    self.cursor += 1
  }
  if braced {
    if digits == 0 || self.cursor == self.limit {
      self.fail("unclosed or empty Unicode escape")
      return regex_literal(0)
    }
    self.cursor += 1
  } else if digits != count {
    self.fail("incomplete hexadecimal escape")
  }
  if value > 0x10FFFF || (value >= 0xD800 && value <= 0xDFFF) {
    self.fail("escape must denote a Unicode scalar, not a surrogate")
  }
  regex_literal(value)
}

///|
fn RegexParser::unit(self : RegexParser, in_class : Bool) -> RegexUnit {
  let c = self.chars[self.cursor]
  self.cursor += 1
  if c != '\\' {
    return regex_literal(c.to_int())
  }
  if self.cursor == self.limit {
    self.fail("trailing escape")
    return regex_literal(0)
  }
  let escaped = self.chars[self.cursor]
  self.cursor += 1
  let ranges : Array[(Int, Int)] = match escaped {
    'd' | 'D' => [(48, 57)]
    'w' | 'W' => [(48, 57), (65, 90), (95, 95), (97, 122)]
    // Deliberately ASCII whitespace; no host-dependent Unicode property tables.
    's' | 'S' => [(9, 13), (32, 32)]
    _ => []
  }
  match escaped {
    'd' | 'w' | 's' => { ranges, literal: None, }
    'D' | 'W' | 'S' =>
      { ranges: regex_ranges_complement(ranges), literal: None, }
    'n' => regex_literal(10)
    'r' => regex_literal(13)
    't' => regex_literal(9)
    'f' => regex_literal(12)
    'v' => regex_literal(11)
    'b' => {
      if !in_class {
        self.fail("word-boundary assertions are unsupported")
      }
      regex_literal(8)
    }
    '0' => {
      if self.cursor < self.limit && self.chars[self.cursor].is_ascii_digit() {
        self.fail("octal escapes are unsupported")
      }
      regex_literal(0)
    }
    'x' => self.hex_escape(2)
    'u' => self.hex_escape(4)
    '1'..='9' => {
      self.fail("backreferences are unsupported")
      regex_literal(0)
    }
    _ => {
      if escaped.is_ascii_alphabetic() {
        self.fail("unsupported escape")
      }
      regex_literal(escaped.to_int())
    }
  }
}

///|
fn RegexParser::character_class(self : RegexParser) -> RegexSyntax {
  self.cursor += 1
  let negated = self.cursor < self.limit && self.chars[self.cursor] == '^'
  if negated {
    self.cursor += 1
  }
  let ranges : Array[(Int, Int)] = []
  while self.cursor < self.limit &&
        self.chars[self.cursor] != ']' &&
        self.error is None {
    let first = self.unit(true)
    if self.cursor + 1 < self.limit &&
      self.chars[self.cursor] == '-' &&
      self.chars[self.cursor + 1] != ']' {
      self.cursor += 1
      let last = self.unit(true)
      match (first.literal, last.literal) {
        (Some(lo), Some(hi)) =>
          if lo <= hi {
            ranges.push((lo, hi))
          } else {
            self.fail("character-class range is reversed")
          }
        _ => self.fail("range endpoints must be literal scalars")
      }
    } else {
      for range in first.ranges {
        ranges.push(range)
      }
    }
  }
  if self.cursor == self.limit {
    self.fail("unclosed character class")
  } else {
    self.cursor += 1
  }
  let folded = self.fold_ranges(ranges)
  RegexAtom(if negated { regex_ranges_complement(folded) } else { folded })
}

///|
fn RegexParser::atom(self : RegexParser) -> RegexSyntax {
  let c = self.chars[self.cursor]
  if c == '(' {
    self.cursor += 1
    self.depth += 1
    if self.depth > 32 {
      self.fail("group nesting exceeds 32")
      return RegexEmpty
    }
    if self.cursor < self.limit && self.chars[self.cursor] == '?' {
      if self.cursor + 1 < self.limit && self.chars[self.cursor + 1] == ':' {
        self.cursor += 2
      } else {
        self.fail("lookaround, named groups and inline flags are unsupported")
        return RegexEmpty
      }
    }
    let inner = self.choice()
    if self.cursor == self.limit || self.chars[self.cursor] != ')' {
      self.fail("unclosed group")
    } else {
      self.cursor += 1
    }
    self.depth -= 1
    return inner
  }
  if c == '[' {
    return self.character_class()
  }
  if c == '.' {
    self.cursor += 1
    return RegexAtom(
      regex_ranges_complement([(10, 10), (13, 13), (0x2028, 0x2029)]),
    )
  }
  if c == '^' || c == '$' {
    self.fail("anchors are supported only at the outer start and end")
    return RegexEmpty
  }
  if c == '*' || c == '+' || c == '?' || c == '{' || c == '}' || c == ']' {
    self.fail("unexpected metacharacter; escape it for a literal")
    return RegexEmpty
  }
  RegexAtom(self.fold_ranges(self.unit(false).ranges))
}

///|
fn RegexParser::count(self : RegexParser) -> Int {
  let start = self.cursor
  let mut value = 0
  while self.cursor < self.limit && self.chars[self.cursor].is_ascii_digit() {
    value = value * 10 + self.chars[self.cursor].to_int() - 48
    self.cursor += 1
    if value > 256 {
      self.fail("repetition bound exceeds 256")
      return 0
    }
  }
  if self.cursor == start {
    self.fail("expected a repetition count")
  }
  value
}

///|
fn RegexParser::repeated(self : RegexParser) -> RegexSyntax {
  let atom = self.atom()
  if self.cursor == self.limit || self.error is Some(_) {
    return atom
  }
  let c = self.chars[self.cursor]
  match c {
    '?' => {
      self.cursor += 1
      RegexRepeat(atom, 0, Some(1))
    }
    '*' => {
      self.cursor += 1
      RegexRepeat(atom, 0, None)
    }
    '+' => {
      self.cursor += 1
      RegexRepeat(atom, 1, None)
    }
    '{' => {
      self.cursor += 1
      let minimum = self.count()
      let mut maximum = Some(minimum)
      if self.cursor < self.limit && self.chars[self.cursor] == ',' {
        self.cursor += 1
        maximum = if self.cursor < self.limit && self.chars[self.cursor] == '}' {
          None
        } else {
          Some(self.count())
        }
      }
      if self.cursor == self.limit || self.chars[self.cursor] != '}' {
        self.fail("unclosed repetition")
      } else {
        self.cursor += 1
      }
      if maximum is Some(maximum) && maximum < minimum {
        self.fail("repetition maximum is below minimum")
      }
      RegexRepeat(atom, minimum, maximum)
    }
    _ => atom
  }
}

///|
fn RegexParser::sequence(self : RegexParser) -> RegexSyntax {
  let nodes : Array[RegexSyntax] = []
  while self.cursor < self.limit && self.error is None {
    let c = self.chars[self.cursor]
    if c == '|' || c == ')' {
      break
    }
    nodes.push(self.repeated())
  }
  if nodes.is_empty() {
    RegexEmpty
  } else {
    RegexSequence(nodes)
  }
}

///|
fn RegexParser::choice(self : RegexParser) -> RegexSyntax {
  let alternatives = [self.sequence()]
  while self.cursor < self.limit &&
        self.chars[self.cursor] == '|' &&
        self.error is None {
    self.cursor += 1
    alternatives.push(self.sequence())
  }
  if alternatives.length() == 1 {
    alternatives[0]
  } else {
    RegexChoice(alternatives)
  }
}

///|
fn RegexCompiler::push(self : RegexCompiler, state : RegexInstruction) -> Int {
  if self.states.length() >= 2048 {
    self.exceeded = true
    return 0
  }
  let index = self.states.length()
  self.states.push(state)
  index
}

///|
fn RegexCompiler::compile(
  self : RegexCompiler,
  syntax : RegexSyntax,
  next : Int,
) -> Int {
  if self.exceeded {
    return 0
  }
  match syntax {
    RegexEmpty => next
    RegexAtom(ranges) => self.push(RegexConsume(ranges, next))
    RegexSequence(nodes) => {
      let mut result = next
      let mut index = nodes.length()
      while index > 0 && !self.exceeded {
        index -= 1
        result = self.compile(nodes[index], result)
      }
      result
    }
    RegexChoice(nodes) => {
      let mut result = self.compile(nodes[0], next)
      for i in 1..<nodes.length() {
        if self.exceeded {
          break
        }
        let branch = self.compile(nodes[i], next)
        result = self.push(RegexFork(result, branch))
      }
      result
    }
    RegexRepeat(child, minimum, maximum) => {
      let mut result = next
      match maximum {
        Some(maximum) =>
          for _ in minimum..<maximum {
            if self.exceeded {
              break
            }
            let branch = self.compile(child, result)
            result = self.push(RegexFork(branch, result))
          }
        None => {
          let repeat = self.push(RegexFork(0, next))
          let body = self.compile(child, repeat)
          if !self.exceeded {
            self.states[repeat] = RegexFork(body, next)
          }
          result = repeat
        }
      }
      for _ in 0..<minimum {
        if self.exceeded {
          break
        }
        result = self.compile(child, result)
      }
      result
    }
  }
}

///|
fn regex_remaining(states : Array[RegexInstruction]) -> Array[Int] {
  let parents : Array[Array[(Int, Int)]] = Array::makei(states.length(), _ => [])
  for index, state in states {
    match state {
      RegexAccept => ()
      RegexConsume(ranges, next) =>
        if !ranges.is_empty() {
          parents[next].push((index, 1))
        }
      RegexFork(left, right) => {
        parents[left].push((index, 0))
        parents[right].push((index, 0))
      }
    }
  }
  // Bucketed 0/1 shortest paths: consuming edges cost one scalar and epsilon
  // edges cost zero. Every reachable minimum is at most the number of states.
  let remaining = Array::make(states.length(), 8193)
  let buckets : Array[Array[Int]] = Array::makei(states.length() + 1, _ => [])
  buckets[0].push(0)
  remaining[0] = 0
  for distance in 0..<=states.length() {
    let pending = buckets[distance]
    while !pending.is_empty() {
      let index = pending.pop().unwrap()
      if remaining[index] == distance {
        for (parent, cost) in parents[index] {
          let candidate = distance + cost
          if candidate <= states.length() && candidate < remaining[parent] {
            remaining[parent] = candidate
            buckets[candidate].push(parent)
          }
        }
      }
    }
  }
  remaining
}

///|
fn regex_finite_capacity(syntax : RegexSyntax) -> Int? {
  match syntax {
    RegexEmpty => Some(0)
    RegexAtom(_) => Some(1)
    RegexSequence(nodes) => {
      let mut total = 0
      for node in nodes {
        match regex_finite_capacity(node) {
          None => return None
          Some(size) => total = (total + size).min(8192)
        }
      }
      Some(total)
    }
    RegexChoice(nodes) => {
      let mut maximum = 0
      for node in nodes {
        match regex_finite_capacity(node) {
          None => return None
          Some(size) => maximum = maximum.max(size)
        }
      }
      Some(maximum)
    }
    RegexRepeat(child, _, maximum) => {
      if maximum is Some(0) {
        return Some(0)
      }
      match regex_finite_capacity(child) {
        Some(0) => Some(0)
        Some(size) =>
          match maximum {
            None => None
            Some(count) => Some((size * count).min(8192))
          }
        None => None
      }
    }
  }
}

///|
fn regex_closure(
  states : Array[RegexInstruction],
  seeds : Array[Int],
) -> Array[Int] {
  let seen = Array::make(states.length(), false)
  let pending = seeds.copy()
  let result : Array[Int] = []
  while !pending.is_empty() {
    let index = pending.pop().unwrap()
    if !seen[index] {
      seen[index] = true
      match states[index] {
        RegexFork(left, right) => {
          pending.push(left)
          pending.push(right)
        }
        RegexAccept | RegexConsume(_, _) => result.push(index)
      }
    }
  }
  result
}

///|
fn regex_class_matches(ranges : Array[(Int, Int)], code : Int) -> Bool {
  let mut lo = 0
  let mut hi = ranges.length()
  while lo < hi {
    let middle = lo + (hi - lo) / 2
    let range = ranges[middle]
    if code < range.0 {
      hi = middle
    } else if code > range.1 {
      lo = middle + 1
    } else {
      return true
    }
  }
  false
}

///|
fn regex_render(
  states : Array[RegexInstruction],
  start : Int,
  remaining : Array[Int],
  max_length : Int,
  text : String,
) -> Result[Render, InputError] {
  if text.length() > 8192 {
    return Err(TooLong(8192))
  }
  let chars = text.to_array()
  if chars.length() > max_length {
    return Err(TooLong(max_length))
  }
  let mut active = regex_closure(states, [start])
  for c in chars {
    let next : Array[Int] = []
    for index in active {
      match states[index] {
        RegexConsume(ranges, target) =>
          if regex_class_matches(ranges, c.to_int()) {
            next.push(target)
          }
        RegexAccept | RegexFork(_, _) => ()
      }
    }
    active = regex_closure(states, next)
    if active.is_empty() {
      return Err(InvalidValue("input cannot match the regular expression"))
    }
  }
  let mut complete = false
  let mut viable = false
  for index in active {
    if index == 0 {
      complete = true
    }
    if chars.length() + remaining[index] <= max_length {
      viable = true
    }
  }
  if !viable {
    return Err(InvalidValue("input cannot match the regular expression"))
  }
  let status = if text.is_empty() {
    Empty
  } else if complete {
    Complete
  } else {
    Incomplete
  }
  Ok(text_render(text, status))
}

///|
/// Compile a full-string regular-expression input mask with viable-prefix edits.
/// Capturing and noncapturing groups, alternation, character classes, dot, and
/// ?, *, +, {m}, {m,n}, {m,} are supported. Optional ^ and $ delimit the whole
/// expression; they are unnecessary because matching is always full-string.
/// \d, \w and \s use ASCII definitions; case_insensitive folds ASCII only.
/// Backreferences, lookaround, inline flags and lazy/possessive quantifiers
/// return InvalidPattern. Source <= 2048 UTF-16 units, nesting <= 32, repetition
/// counts <= 256, compiled states <= 2048, editable input <= 8192 UTF-16 units.
/// max_length optionally imposes a smaller scalar limit, including viable
/// continuations; finite expressions expose their inferred scalar capacity.
pub fn regex(
  source : String,
  case_insensitive? : Bool = false,
  max_length? : Int = 8192,
) -> Result[Mask, InputError] {
  if max_length < 1 || max_length > 8192 {
    return Err(InvalidConfig("regex maximum length must be 1..8192 scalars"))
  }
  if source.length() > 2048 {
    return Err(
      InvalidPattern("regular-expression source exceeds 2048 UTF-16 units"),
    )
  }
  let chars = source.to_array()
  let start = if !chars.is_empty() && chars[0] == '^' { 1 } else { 0 }
  let mut limit = chars.length()
  if limit > start && chars[limit - 1] == '$' {
    let mut slashes = 0
    let mut index = limit - 1
    while index > start && chars[index - 1] == '\\' {
      slashes += 1
      index -= 1
    }
    if slashes % 2 == 0 {
      limit -= 1
    }
  }
  let parser : RegexParser = {
    chars,
    limit,
    case_insensitive,
    cursor: start,
    depth: 0,
    error: None,
  }
  let syntax = parser.choice()
  if parser.cursor != limit {
    parser.fail("unexpected closing group")
  }
  if parser.error is Some(message) {
    return Err(InvalidPattern(message))
  }
  let compiler : RegexCompiler = { states: [RegexAccept], exceeded: false, }
  let start = compiler.compile(syntax, 0)
  if compiler.exceeded {
    return Err(
      InvalidPattern("compiled regular expression exceeds 2048 states"),
    )
  }
  let states = compiler.states
  let remaining = regex_remaining(states)
  if remaining[start] == 8193 {
    return Err(InvalidPattern("regular expression accepts no possible input"))
  }
  if remaining[start] > max_length {
    return Err(
      InvalidConfig("regex maximum length cannot fit any complete value"),
    )
  }
  let capacity = regex_finite_capacity(syntax)
    .unwrap_or(max_length)
    .min(max_length)
  Ok(
    extension(
      text => regex_render(states, start, remaining, max_length, text),
      capacity~,
    ),
  )
}
