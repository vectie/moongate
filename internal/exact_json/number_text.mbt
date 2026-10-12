///|
// The pinned JSON parser rounds some finite decimals and does not retain their
// repr. Validate JSON normally, then parse a parallel tree whose number tokens
// are strings. Pairing by object key/array index preserves duplicate-key parser
// semantics and never treats an original numeric string as a number.
pub fn parse_with_number_text(
  source : StringView,
) -> Json raise @json.ParseError {
  let value = @json.parse(source)
  let quoted = StringBuilder()
  let mut start = 0
  let mut in_string = false
  let mut escaped = false
  for i = 0; i < source.length(); {
    let c = source[i]
    if in_string {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        in_string = false
      }
      continue i + 1
    }
    if c == '"' {
      in_string = true
      continue i + 1
    }
    if c == '-' || (c >= '0' && c <= '9') {
      let mut end = i + 1
      while end < source.length() &&
            (
              (source[end] >= '0' && source[end] <= '9') ||
              source[end] == '.' ||
              source[end] == 'e' ||
              source[end] == 'E' ||
              source[end] == '+' ||
              source[end] == '-'
            ) {
        end += 1
      }
      quoted.write_view(source[start:i])
      quoted.write_char('"')
      quoted.write_view(source[i:end])
      quoted.write_char('"')
      start = end
      continue end
    }
    continue i + 1
  }
  quoted.write_view(source[start:])
  attach_number_text(value, @json.parse(quoted.to_string()))
}

///|
fn attach_number_text(value : Json, lexical : Json) -> Json {
  match (value, lexical) {
    (Number(n, ..), String(text)) => Json::number(n, repr=text)
    (Array(values), Array(raw)) =>
      Json::array(values.mapi((i, v) => attach_number_text(v, raw[i])))
    (Object(values), Object(raw)) => {
      for key, v in values {
        values[key] = attach_number_text(v, raw[key])
      }
      Json::object(values)
    }
    _ => value
  }
}

///|
// Interpret the already grammar-validated decimal lexeme exactly. Remove only
// zero fractional digits, bound the final integer by decimal length, and build
// at most 16 digits using Int64 before converting a verified safe value.
pub fn exact_count(text : String) -> Double? {
  if text.is_empty() {
    return None
  }
  let negative = text[0] == '-'
  let digits = StringBuilder()
  let mut fraction = 0
  let mut decimal = false
  let mut exponent_start = text.length()
  for i = (if negative { 1 } else { 0 }); i < text.length(); i = i + 1 {
    let c = text[i]
    if c == 'e' || c == 'E' {
      exponent_start = i + 1
      break
    } else if c == '.' {
      decimal = true
    } else if c >= '0' && c <= '9' {
      digits.write_view(text[i:i + 1])
      if decimal {
        fraction += 1
      }
    } else {
      return None
    }
  }
  let digits = digits.to_string()
  let mut first = 0
  while first < digits.length() && digits[first] == '0' {
    first += 1
  }
  if first == digits.length() {
    return Some(0.0)
  }
  if negative {
    return None
  }
  let mut exponent = 0
  let mut exponent_negative = false
  let mut begin = exponent_start
  if begin < text.length() && (text[begin] == '+' || text[begin] == '-') {
    exponent_negative = text[begin] == '-'
    begin += 1
  }
  // Larger magnitudes cannot yield a safe nonzero integer from this mantissa.
  let cap = text.length() + 16
  for i = begin; i < text.length(); i = i + 1 {
    let digit = text[i].to_int() - '0'
    if digit < 0 || digit > 9 || exponent > (cap - digit) / 10 {
      return None
    }
    exponent = exponent * 10 + digit
  }
  if exponent_negative {
    exponent = -exponent
  }
  let shift = exponent - fraction
  let length = digits.length() - first + shift
  if length <= 0 || length > 16 {
    return None
  }
  let end = digits.length() + (if shift < 0 { shift } else { 0 })
  if end <= first {
    return None
  }
  for i = end; i < digits.length(); i = i + 1 {
    if digits[i] != '0' {
      return None
    }
  }
  let mut value = 0L
  for i = first; i < end; i = i + 1 {
    value = value * 10L + (digits[i].to_int() - '0').to_int64()
  }
  for i = 0; i < shift; i = i + 1 {
    value *= 10L
  }
  if value > 9007199254740991L {
    None
  } else {
    Some(value.to_double())
  }
}
