///|
fn regex_editor(source : String, text : String) -> @mooninput.Editor {
  @mooninput.Editor::new(@mooninput.regex(source).unwrap(), initial=text).unwrap()
}

///|
test "regex typing accepts viable prefixes and rejects impossible edits atomically" {
  let mask = @mooninput.regex("^AB-\\d{2,4}$").unwrap()
  let empty = @mooninput.Editor::new(mask).unwrap()
  assert_eq(empty.status(), @mooninput.Empty)
  let a = empty.insert("A").unwrap()
  assert_eq(a.status(), @mooninput.Incomplete)
  let prefix = a.insert("B-1").unwrap()
  assert_eq(prefix.display(), "AB-1")
  assert_eq(prefix.status(), @mooninput.Incomplete)
  let complete = prefix.insert("2").unwrap()
  assert_eq(complete.value(), Ok("AB-12"))
  assert_eq(complete.insert("34").unwrap().value(), Ok("AB-1234"))
  assert_true(complete.insert("x") is Err(_))
  assert_true(complete.insert("345") is Err(_))
  assert_eq(complete.raw(), "AB-12")
  assert_eq(complete.backspace().unwrap().status(), @mooninput.Incomplete)
  assert_eq(mask.format("AB-123"), Ok("AB-123"))
  assert_true(mask.format("XAB-123") is Err(_))
  assert_true(mask.format("AB-123X") is Err(_))
}

///|
test "regex optional groups and alternative branches remain editable" {
  let source = "(?:INV|PO)-[A-Z]{2}(?:/\\d{2})?"
  assert_eq(regex_editor(source, "I").status(), @mooninput.Incomplete)
  assert_eq(regex_editor(source, "P").status(), @mooninput.Incomplete)
  assert_eq(regex_editor(source, "INV-AB").status(), @mooninput.Complete)
  assert_eq(regex_editor(source, "PO-CD/").status(), @mooninput.Incomplete)
  assert_eq(regex_editor(source, "PO-CD/12").value(), Ok("PO-CD/12"))
  assert_true(@mooninput.regex(source).unwrap().format("INX") is Err(_))
  let original = regex_editor(source, "INV-AB/12")
  let revised = original.select(4, 6).unwrap().insert("CD").unwrap()
  assert_eq(revised.value(), Ok("INV-CD/12"))
  assert_eq(revised.selection(), { start: 6, end: 6, })
}

///|
test "regex character classes ranges escaped punctuation and ASCII case folding" {
  let mask = @mooninput.regex("[A-F][^0-9]\\w\\s\\D\\W\\S").unwrap()
  assert_eq(mask.format("F_a x!z"), Ok("F_a x!z"))
  assert_true(mask.format("G_a x!z") is Err(_))
  assert_true(mask.format("F1a x!z") is Err(_))
  assert_true(mask.format("F_a x! ") is Err(_))
  assert_true(mask.format("F_a 9!z") is Err(_))
  let punctuation = @mooninput.regex("[\\]\\-\\\\]{3}").unwrap()
  assert_eq(punctuation.format("]-\\"), Ok("]-\\"))
  let folded = @mooninput.regex("ab[A-D][^E]", case_insensitive=true).unwrap()
  assert_eq(folded.format("ABcd"), Ok("ABcd"))
  assert_true(folded.format("ABce") is Err(_))
  assert_true(folded.format("ABcE") is Err(_))
  assert_true(@mooninput.regex("ab").unwrap().format("AB") is Err(_))
  assert_eq(@mooninput.regex("[\\D\\d]").unwrap().format("😀"), Ok("😀"))
  assert_true(@mooninput.regex("[^\\s\\S]") is Err(_))
}

///|
test "regex dot Unicode literals and escapes use scalar positions across targets" {
  let source = "😀.\\u{1F680}\\x41\\u0042"
  let editor = regex_editor(source, "😀中🚀AB")
  assert_eq(editor.value(), Ok("😀中🚀AB"))
  assert_eq(editor.selection(), { start: 7, end: 7, })
  assert_eq(editor.select(1, 2).unwrap().selection(), { start: 0, end: 2, })
  assert_eq(regex_editor("..", "😀").status(), @mooninput.Incomplete)
  assert_true(@mooninput.regex(".").unwrap().format("\n") is Err(_))
  assert_true(@mooninput.regex(".").unwrap().format("\r") is Err(_))
  assert_true(@mooninput.regex(".").unwrap().format("\u2028") is Err(_))
  assert_eq(@mooninput.regex("[^]").unwrap().format("\n"), Ok("\n"))
  assert_eq(
    @mooninput.regex("\\t\\r\\n").unwrap().format("\t\r\n"),
    Ok("\t\r\n"),
  )
  assert_eq(@mooninput.regex("\\0").unwrap().format("\u0000"), Ok("\u0000"))
  assert_eq(@mooninput.regex("[\\b]").unwrap().format("\u0008"), Ok("\u0008"))
}

///|
test "regex finite and open repetition include their exact endpoints" {
  assert_eq(regex_editor("a{2}", "a").status(), @mooninput.Incomplete)
  assert_eq(regex_editor("a{2}", "aa").status(), @mooninput.Complete)
  assert_true(@mooninput.regex("a{2}").unwrap().format("aaa") is Err(_))
  assert_eq(regex_editor("a{1,3}", "a").status(), @mooninput.Complete)
  assert_eq(regex_editor("a{1,3}", "aaa").status(), @mooninput.Complete)
  assert_true(@mooninput.regex("a{1,3}").unwrap().format("aaaa") is Err(_))
  assert_eq(regex_editor("a{2,}", "aaaaa").status(), @mooninput.Complete)
  assert_eq(regex_editor("a?b*c+", "c").status(), @mooninput.Complete)
  assert_eq(regex_editor("a?b*c+", "abbbcc").value(), Ok("abbbcc"))
  assert_eq(regex_editor("a{0}b", "b").value(), Ok("b"))
  assert_eq(regex_editor("(a|)b", "b").value(), Ok("b"))
  assert_eq(@mooninput.regex("").unwrap().format(""), Ok(""))
  assert_true(@mooninput.regex("").unwrap().format("a") is Err(_))
  assert_eq(@mooninput.regex("^$").unwrap().format(""), Ok(""))
  assert_eq(@mooninput.regex("\\^a\\$").unwrap().format("^a$"), Ok("^a$"))
}

///|
test "regex configuration rejects malformed or unsupported syntax clearly" {
  for
    source in [
      "(", ")", "[abc", "[z-a]", "[a-\\d]", "[\\w-z]", "a{", "a{}", "a{2,1}", "a{1,x}",
      "a{257}", "a{99999999999999999}", "a**", "a+?", "a*+", "a{2}?", "^a$b", "a^",
      "(?=a)", "(?!a)", "(?<=a)", "(?<name>a)", "(?i:a)", "(a)\\1", "\\bword", "\\p{L}",
      "\\q", "\\12", "\\01", "\\x4", "\\xGG", "\\u123", "\\u{}", "\\u{123", "\\u{110000}",
      "\\u{1234567}", "\\uD800", "\\", "[]",
    ] {
    match @mooninput.regex(source) {
      Err(@mooninput.InvalidPattern(message)) =>
        assert_true(!message.is_empty())
      _ => fail("expected InvalidPattern for \{source}")
    }
  }
}

///|
test "regex compilation input and nesting have explicit resource limits" {
  assert_true(@mooninput.regex(String::make(2049, 'a')) is Err(_))
  let mut nested = "a"
  for _ in 0..<32 {
    nested = "(\{nested})"
  }
  assert_eq(@mooninput.regex(nested).unwrap().format("a"), Ok("a"))
  assert_true(@mooninput.regex("(\{nested})") is Err(_))
  assert_true(@mooninput.regex("(a{256}){256}") is Err(_))
  let mask = @mooninput.regex("a*").unwrap()
  assert_eq(mask.format(String::make(8192, 'a')), Ok(String::make(8192, 'a')))
  assert_eq(mask.format(String::make(8193, 'a')), Err(@mooninput.TooLong(8192)))
}

///|
test "regex nested nullable repetition terminates without backtracking" {
  let nested = @mooninput.regex("(a+)+b").unwrap()
  let long = String::make(1000, 'a')
  assert_eq(nested.format(long), Ok(long))
  assert_eq(nested.format(long + "b"), Ok(long + "b"))
  assert_true(nested.format(long + "c") is Err(_))
  let nullable = @mooninput.regex("((a?)*)*b").unwrap()
  assert_eq(nullable.format("b"), Ok("b"))
  assert_eq(nullable.format("aaab"), Ok("aaab"))
  assert_eq(regex_editor("((a?)*)*b", "aaa").status(), @mooninput.Incomplete)
  assert_true(nullable.format("aaac") is Err(_))
}

///|
test "regex finite language is checked exhaustively against an independent word oracle" {
  let words : Array[String] = []
  let mut stems = [""]
  for _ in 0..<3 {
    let next : Array[String] = []
    for stem in stems {
      for letter in ["a", "b"] {
        let stem = stem + letter
        next.push(stem)
        for suffix in ["xy", "z", ""] {
          words.push(stem + suffix)
        }
      }
    }
    stems = next
  }
  let mask = @mooninput.regex("^[ab]{1,3}(xy|z?)$").unwrap()
  let mut candidates = [""]
  for length in 0..<6 {
    let next : Array[String] = []
    for candidate in candidates {
      let mut viable = false
      let mut complete = false
      for word in words {
        if word.has_prefix(candidate) {
          viable = true
        }
        if word == candidate {
          complete = true
        }
      }
      let result = @mooninput.Editor::new(mask, initial=candidate)
      if viable {
        let editor = result.unwrap()
        let expected = if candidate.is_empty() {
          @mooninput.Empty
        } else if complete {
          @mooninput.Complete
        } else {
          @mooninput.Incomplete
        }
        assert_eq(editor.status(), expected)
      } else {
        assert_true(result is Err(_))
      }
      if length < 5 {
        for letter in ["a", "b", "x", "y", "z"] {
          next.push(candidate + letter)
        }
      }
    }
    candidates = next
  }
}

///|
test "regex inferred finite capacities support composition and arbitrary child repetition" {
  let letters = @mooninput.regex("[A-Z]{2}").unwrap()
  assert_eq(letters.capacity(), 2)
  assert_eq(@mooninput.regex("a(?:bc|d){2,4}").unwrap().capacity(), 9)
  assert_eq(@mooninput.regex("😀{2}").unwrap().capacity(), 2)
  let code = @mooninput.composite([
    @mooninput.Block("letters", letters),
    @mooninput.Literal("-"),
    @mooninput.Block("digits", @mooninput.regex("\\d{3}").unwrap()),
  ]).unwrap()
  let editor = @mooninput.Editor::new(code, initial="AB123").unwrap()
  assert_eq(editor.display(), "AB-123")
  assert_eq(editor.value(), Ok("AB-123"))
  assert_eq(editor.fields()[0].value, "AB")
  assert_eq(code.format("AB-123"), Ok("AB-123"))
  let repeated = @mooninput.repeat(letters, 1, 3).unwrap()
  assert_eq(repeated.capacity(), 6)
  assert_eq(
    @mooninput.Editor::new(repeated, initial="ABCD").unwrap().value(),
    Ok("ABCD"),
  )
  assert_eq(
    @mooninput.Editor::new(repeated, initial="ABC").unwrap().status(),
    @mooninput.Incomplete,
  )
}

///|
test "regex explicit scalar limits constrain viable continuations and unbounded masks" {
  let bounded = @mooninput.regex("[A-Z]+", max_length=4).unwrap()
  assert_eq(bounded.capacity(), 4)
  assert_eq(bounded.format("ABCD"), Ok("ABCD"))
  assert_eq(bounded.format("ABCDE"), Err(@mooninput.TooLong(4)))
  assert_eq(@mooninput.regex("a{1,5}", max_length=3).unwrap().capacity(), 3)
  assert_true(@mooninput.regex("abc", max_length=2) is Err(_))
  assert_true(@mooninput.regex("a", max_length=0) is Err(_))
  assert_true(@mooninput.regex("a", max_length=8193) is Err(_))
  let short = @mooninput.regex("a|bc", max_length=1).unwrap()
  assert_eq(short.format("a"), Ok("a"))
  assert_true(short.format("b") is Err(_))
  let emoji = @mooninput.regex(".+", max_length=2).unwrap()
  assert_eq(emoji.format("😀🚀"), Ok("😀🚀"))
  assert_eq(emoji.format("😀🚀a"), Err(@mooninput.TooLong(2)))
}
