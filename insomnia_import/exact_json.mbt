///|
priv struct ExactJsonReader {
  chars : Array[Char]
  mut position : Int32
}

///|
fn ExactJsonReader::space(self : ExactJsonReader) -> Unit {
  while self.position < self.chars.length() &&
        [' ', '\t', '\r', '\n'].contains(self.chars[self.position]) {
    self.position += 1
  }
}

///|
fn ExactJsonReader::string(self : ExactJsonReader) -> String raise {
  let token = StringBuilder()
  token.write_char('"')
  self.position += 1
  while self.position < self.chars.length() {
    let ch = self.chars[self.position]
    token.write_char(ch)
    self.position += 1
    if ch == '\\' {
      token.write_char(self.chars[self.position])
      self.position += 1
    } else if ch == '"' {
      break
    }
  }
  guard @json.parse(token.to_string()) is String(value) else {
    fail("Insomnia invalid JSON string")
  }
  value
}

///|
// Called only after the standard parser validates syntax, Unicode and nesting.
// Preserve exact decimal tokens before any integer or whole-frame conversion.
fn ExactJsonReader::value(self : ExactJsonReader) -> Json raise {
  self.space()
  match self.chars[self.position] {
    '{' => {
      self.position += 1
      self.space()
      let fields : Map[String, Json] = Map([])
      if self.chars[self.position] != '}' {
        while true {
          let key = self.string()
          guard !fields.contains(key) else {
            fail("Insomnia JSON has duplicate object keys")
          }
          self.space()
          self.position += 1
          fields[key] = self.value()
          self.space()
          if self.chars[self.position] == '}' {
            break
          }
          self.position += 1
          self.space()
        }
      }
      self.position += 1
      Json::object(fields)
    }
    '[' => {
      self.position += 1
      self.space()
      let values : Array[Json] = []
      if self.chars[self.position] != ']' {
        while true {
          values.push(self.value())
          self.space()
          if self.chars[self.position] == ']' {
            break
          }
          self.position += 1
        }
      }
      self.position += 1
      Json::array(values)
    }
    '"' => Json::string(self.string())
    _ => {
      let token = StringBuilder()
      while self.position < self.chars.length() &&
            ![' ', '\t', '\r', '\n', ',', '}', ']'].contains(
              self.chars[self.position],
            ) {
        token.write_char(self.chars[self.position])
        self.position += 1
      }
      let spelling = token.to_string()
      match @json.parse(spelling) {
        Number(n, ..) => Json::number(n, repr=spelling)
        value => value
      }
    }
  }
}

///|
fn parse_exact_json(text : String) -> Json raise {
  @json.parse(text) |> ignore
  let reader : ExactJsonReader = { chars: text.iter().collect(), position: 0, }
  reader.value()
}

///|
// A syntax-validated JSON decimal denotes an integer only if its significant
// coefficient has no fractional remainder after its exact decimal exponent.
fn exact_integer(spelling : String) -> Int64? {
  let chars = spelling.iter().collect()
  let negative = chars[0] == '-'
  let digits : Array[Int32] = []
  let mut fraction = 0
  let mut point = false
  let mut cursor = if negative { 1 } else { 0 }
  while cursor < chars.length() && chars[cursor] != 'e' && chars[cursor] != 'E' {
    if chars[cursor] == '.' {
      point = true
    } else {
      digits.push(chars[cursor].to_int() - 48)
      if point {
        fraction += 1
      }
    }
    cursor += 1
  }
  let mut exponent = 0
  let mut negative_exponent = false
  if cursor < chars.length() {
    cursor += 1
    if chars[cursor] == '-' || chars[cursor] == '+' {
      negative_exponent = chars[cursor] == '-'
      cursor += 1
    }
    let cap = chars.length() + 32
    while cursor < chars.length() {
      exponent = (exponent * 10 + chars[cursor].to_int() - 48).min(cap)
      cursor += 1
    }
  }
  if negative_exponent {
    exponent = -exponent
  }
  let mut first = 0
  while first < digits.length() && digits[first] == 0 {
    first += 1
  }
  if first == digits.length() {
    return Some(0L)
  }
  let mut end = digits.length()
  while digits[end - 1] == 0 {
    end -= 1
  }
  let power = exponent - fraction + digits.length() - end
  if power < 0 || end - first + power > 10 {
    return None
  }
  let mut value = 0L
  for i in first..<end {
    value = value * 10L + digits[i].to_int64()
  }
  for _ in 0..<power {
    value *= 10L
  }
  Some(if negative { -value } else { value })
}
