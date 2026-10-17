///|
// Syntax is validated before this scan. A string followed by a colon is an
// object key; scopes track decoded keys, including Unicode-escaped duplicates.
fn reject_duplicate_keys(source : String) -> Unit raise {
  let scopes : Array[Map[String, Bool]] = []
  for i = 0; i < source.length(); {
    if source[i] == '{' {
      scopes.push(Map([]))
    } else if source[i] == '}' {
      ignore(scopes.pop())
    } else if source[i] == '"' {
      let mut end = i + 1
      while source[end] != '"' {
        if source[end] == '\\' {
          end += 1
        }
        end += 1
      }
      end += 1
      let mut next = end
      while next < source.length() &&
            (
              source[next] == ' ' ||
              source[next] == '\t' ||
              source[next] == '\r' ||
              source[next] == '\n'
            ) {
        next += 1
      }
      if next < source.length() && source[next] == ':' {
        guard @json.parse(source[i:end]) is String(key) else {
          fail("Invalid object key")
        }
        let keys = scopes[scopes.length() - 1]
        if keys.contains(key) {
          fail("Responses JSON contains duplicate decoded object keys")
        }
        keys[key] = true
      }
      continue end
    }
    continue i + 1
  }
}
