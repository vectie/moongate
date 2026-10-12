///|
priv struct MoonNetworkUrlTarget {
  origin : String
  path : String
}

///|
fn moon_network_url_control_free(value : String) -> Bool {
  for char in value {
    let code = char.to_int()
    if code <= 32 || code == 127 {
      return false
    }
  }
  true
}

///|
fn moon_network_hex_digit(char : Char) -> Bool {
  (char >= '0' && char <= '9') ||
  (char >= 'a' && char <= 'f') ||
  (char >= 'A' && char <= 'F')
}

///|
fn moon_network_url_userinfo_valid(value : String) -> Bool {
  for char in value {
    if char.to_int() > 127 {
      return false
    }
  }
  let mut index = 0
  while index < value.length() {
    let char = value.get_char(index).unwrap()
    if char == '%' {
      if index + 2 >= value.length() ||
        !moon_network_hex_digit(value.get_char(index + 1).unwrap()) ||
        !moon_network_hex_digit(value.get_char(index + 2).unwrap()) {
        return false
      }
      index += 3
      continue
    }
    if !((char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') ||
      "-._~!$&'()*+,;=:".contains(char.to_string())) {
      return false
    }
    index += 1
  }
  true
}

///|
fn moon_network_ipv4_host_valid(host : String) -> Bool {
  let segments = host.split(".").collect()
  if segments.length() != 4 {
    return false
  }
  for segment in segments {
    if segment.is_empty() || segment.length() > 3 {
      return false
    }
    for char in segment {
      if char < '0' || char > '9' {
        return false
      }
    }
    let value = @string.parse_int(segment.to_owned()) catch {
      _ => return false
    }
    if value > 255 {
      return false
    }
  }
  true
}

///|
fn moon_network_host_syntax_valid(host : String) -> Bool {
  if host.is_empty() || host.length() > 253 {
    return false
  }
  if host.contains(":") {
    if host.length() > 45 || host.contains(":::") {
      return false
    }
    let compression = host.split("::").collect()
    if compression.length() > 2 {
      return false
    }
    let segments = host.split(":").collect()
    let mut units = 0
    for index, segment in segments {
      if segment.is_empty() {
        continue
      }
      if segment.contains(".") {
        if index != segments.length() - 1 ||
          !moon_network_ipv4_host_valid(segment.to_owned()) {
          return false
        }
        units += 2
        continue
      }
      if segment.length() > 4 {
        return false
      }
      for char in segment {
        if !((char >= '0' && char <= '9') ||
          (char >= 'a' && char <= 'f') ||
          (char >= 'A' && char <= 'F')) {
          return false
        }
      }
      units += 1
    }
    if compression.length() == 2 {
      return units < 8
    }
    return units == 8
  }
  let mut numeric = true
  for char in host {
    if !((char >= '0' && char <= '9') || char == '.') {
      numeric = false
    }
  }
  if numeric {
    return moon_network_ipv4_host_valid(host)
  }
  if host.has_prefix(".") || host.has_suffix(".") || host.contains("..") {
    return false
  }
  for label in host.split(".") {
    if label.is_empty() ||
      label.length() > 63 ||
      label.has_prefix("-") ||
      label.has_suffix("-") {
      return false
    }
    for char in label {
      if !((char >= 'a' && char <= 'z') ||
        (char >= 'A' && char <= 'Z') ||
        (char >= '0' && char <= '9') ||
        char == '-' ||
        char == '_') {
        return false
      }
    }
  }
  true
}

///|
fn moon_network_url_authority_end(rest : StringView) -> Int {
  let mut end = rest.length()
  for delimiter in ["/", "?", "#"] {
    match rest.find(delimiter) {
      Some(index) if index < end => end = index
      _ => ()
    }
  }
  end
}

///|
fn moon_parse_network_url(
  url : String,
  schemes : ArrayView[String],
  allow_credentials? : Bool = false,
) -> Result[MoonNetworkUrlTarget, String] {
  if url.is_empty() ||
    url.length() > 16_384 ||
    url.trim() != url ||
    !moon_network_url_control_free(url) ||
    url.contains("\\") ||
    url.contains("#") {
    return Err("invalid network URL")
  }
  guard url.find("://") is Some(scheme_end) else {
    return Err("invalid network URL")
  }
  let scheme = url[:scheme_end].to_owned()
  if !schemes.contains(scheme) {
    return Err("invalid network URL scheme")
  }
  let authority_start = scheme_end + 3
  let rest = url[authority_start:]
  let authority_end = moon_network_url_authority_end(rest)
  let raw_authority = rest[:authority_end].to_owned()
  if raw_authority.is_empty() {
    return Err("invalid network URL authority")
  }
  let host_authority = match raw_authority.split("@").collect() {
    [host] => host.to_owned()
    [credentials, host] if allow_credentials &&
      !credentials.is_empty() &&
      moon_network_url_userinfo_valid(credentials.to_owned()) &&
      !host.is_empty() => host.to_owned()
    _ => return Err("invalid network URL credentials")
  }
  guard moongate_parse_authority(host_authority) is Some(_) else {
    return Err("invalid network URL authority")
  }
  let remainder = rest[authority_end:].to_owned()
  let path = if remainder.is_empty() {
    "/"
  } else if remainder.has_prefix("?") {
    "/\{remainder}"
  } else {
    remainder
  }
  Ok({ origin: "\{scheme}://\{raw_authority}", path, })
}
