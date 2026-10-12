///|
/// Tokenize a deliberately bounded POSIX curl paste, never executing a shell.
fn words(source : String) -> Array[String] raise {
  guard source.length() <= 1048576 else { fail("curl input exceeds 1 MiB") }
  let result : Array[String] = []
  let word = StringBuilder()
  let mut quote : Char = '\u{0}'
  let mut escaped = false
  let mut started = false
  for c in source {
    if escaped {
      if c != '\n' {
        if quote == '"' && c != '"' && c != '\\' && c != '$' && c != '`' {
          word.write_char('\\')
        }
        word.write_char(c)
        started = true
      }
      escaped = false
    } else if quote == '\'' {
      if c == '\'' {
        quote = '\u{0}'
      } else {
        word.write_char(c)
      }
    } else if c == '\\' {
      escaped = true
    } else if c == '$' || c == '`' {
      fail("shell expansion is unsupported; paste literal values")
    } else if quote == '"' {
      if c == '"' {
        quote = '\u{0}'
      } else {
        word.write_char(c)
      }
    } else if c == '\'' || c == '"' {
      quote = c
      started = true
    } else if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      if started {
        result.push(word.to_string())
        word.reset()
        started = false
      }
    } else if c == ';' ||
      c == '|' ||
      c == '&' ||
      c == '<' ||
      c == '>' ||
      c == '(' ||
      c == ')' ||
      c == '#' {
      fail("shell operators and comments are unsupported")
    } else {
      word.write_char(c)
      started = true
    }
  }
  guard quote == '\u{0}' && !escaped else { fail("unfinished quote or escape") }
  if started {
    result.push(word.to_string())
  }
  result
}

///|
fn token(value : String) -> Bool {
  !value.is_empty() &&
  value
  .iter()
  .all(c => {
    (c >= 'A' && c <= 'Z') ||
    (c >= 'a' && c <= 'z') ||
    (c >= '0' && c <= '9') ||
    "!#$%&'*+-.^_`|~".contains(c.to_string())
  })
}

///|
/// Convert one literal curl request to an editable HTTP-client document.
/// Unsupported options fail rather than silently changing request semantics.
pub fn to_http(source : String) -> String raise {
  let args = words(source)
  guard args.get(0) == Some("curl") else { fail("expected a curl command") }
  let mut url : String? = None
  let mut request_method : String? = None
  let mut body : String? = None
  let headers : Array[(String, String)] = []
  let mut json_body = false
  let mut form_body = false
  let mut head = false
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "-s" ||
      arg == "--silent" ||
      arg == "-S" ||
      arg == "--show-error" ||
      arg == "-sS" ||
      arg == "--compressed" {
      i += 1
      continue
    }
    if arg == "-I" || arg == "--head" {
      head = true
      i += 1
      continue
    }
    if arg == "-X" ||
      arg == "--request" ||
      arg == "-H" ||
      arg == "--header" ||
      arg == "--url" ||
      arg == "-d" ||
      arg == "--data" ||
      arg == "--data-raw" ||
      arg == "--data-binary" ||
      arg == "--json" {
      guard args.get(i + 1) is Some(value) else {
        fail("missing curl option value")
      }
      match arg {
        "-X" | "--request" => {
          guard request_method is None && token(value) else {
            fail("invalid or repeated method")
          }
          request_method = Some(value)
        }
        "-H" | "--header" => {
          guard value.find(":") is Some(colon) else {
            fail("expected header name: value")
          }
          let name = value[:colon].to_owned()
          let content = value[colon + 1:].trim().to_owned()
          guard token(name) &&
            !value.iter().any(c => (c < ' ' && c != '\t') || c == '\u{7f}') else {
            fail("invalid header")
          }
          guard !content.is_empty() else {
            fail("header removal syntax is unsupported")
          }
          headers.push((name, content))
        }
        "--url" => {
          guard url is None else { fail("multiple URLs are unsupported") }
          url = Some(value)
        }
        _ => {
          guard body is None else {
            fail("multiple body arguments are unsupported")
          }
          guard arg == "--data-raw" || !value.has_prefix("@") else {
            fail("file body references are unsupported")
          }
          guard (arg != "--data" && arg != "-d") ||
            (!value.contains("\n") && !value.contains("\r")) else {
            fail("use --data-raw for a literal multiline body")
          }
          guard !head else { fail("HEAD with a body is unsupported") }
          body = Some(value)
          json_body = arg == "--json"
          form_body = !json_body
        }
      }
      i += 2
    } else if arg.has_prefix("-") {
      fail("unsupported curl option")
    } else {
      guard url is None else { fail("multiple URLs are unsupported") }
      url = Some(arg)
      i += 1
    }
  }
  guard url is Some(address) else { fail("missing URL") }
  guard address.has_prefix("https://") || address.has_prefix("http://") else {
    fail("expected HTTP(S) URL")
  }
  guard !address.iter().any(c => c <= ' ' || c == '\u{7f}') else {
    fail("invalid URL whitespace")
  }
  let authority = address.split("://").to_array()[1].split("/").to_array()[0]
    .split("?")
    .to_array()[0]
    .split("#")
    .to_array()[0]
  guard !authority.is_empty() && !authority.contains("@") else {
    fail("empty host or URL credentials are unsupported")
  }
  // curl expands URL braces/ranges even inside shell quotes. Preserve only the
  // bracket pair belonging to an IPv6 host; never flatten a multi-request curl.
  guard !address.contains("{") && !address.contains("}") else {
    fail("curl URL globbing is unsupported")
  }
  let scheme_length = if address.has_prefix("https://") { 8 } else { 7 }
  let suffix = address[scheme_length + authority.length():]
  guard !suffix.contains("[") && !suffix.contains("]") else {
    fail("curl URL globbing is unsupported")
  }
  if authority.contains("[") || authority.contains("]") {
    guard authority.has_prefix("[") && authority.find("]") is Some(close) else {
      fail("curl URL globbing is unsupported")
    }
    let host = authority[1:close]
    let port = authority[close + 1:]
    guard host.contains(":") &&
      !host.contains("[") &&
      !host.contains("]") &&
      (
        port.is_empty() ||
        (
          port.has_prefix(":") &&
          port.length() > 1 &&
          port[1:].iter().all(c => c >= '0' && c <= '9')
        )
      ) else {
      fail("curl URL globbing is unsupported")
    }
  }
  guard !(head && body is Some(_)) else {
    fail("HEAD with a body is unsupported")
  }
  let verb = request_method.unwrap_or_else(fn() {
    if head {
      "HEAD"
    } else if body is Some(_) {
      "POST"
    } else {
      "GET"
    }
  })
  let out = StringBuilder()
  out.write_string(
    "# Imported curl request. Review before sending; nothing was executed.\n",
  )
  let mut secret = 0
  let rendered : Array[String] = []
  let mut content_type = false
  let mut accept = false
  for (name, value) in headers {
    let lower = name.to_lower()
    if lower == "content-type" {
      content_type = true
    }
    if lower == "accept" {
      accept = true
    }
    if lower == "authorization" ||
      lower == "proxy-authorization" ||
      lower == "cookie" ||
      lower.contains("api-key") ||
      lower.contains("apikey") ||
      lower.contains("token") ||
      lower.contains("secret") {
      secret += 1
      out.write_string("@credential_\{secret} = REPLACE_ME\n")
      rendered.push("\{name}: {{credential_\{secret}}}")
    } else {
      rendered.push("\{name}: \{value}")
    }
  }
  out.write_string("\n### Imported curl\n\{verb} \{address}\n")
  for header in rendered {
    out.write_string(header + "\n")
  }
  if !content_type && (json_body || form_body) {
    out.write_string(
      if json_body {
        "Content-Type: application/json\n"
      } else {
        "Content-Type: application/x-www-form-urlencoded\n"
      },
    )
  }
  if json_body && !accept {
    out.write_string("Accept: application/json\n")
  }
  if body is Some(value) {
    out.write_string("\n" + value + "\n")
  }
  out.to_string()
}
