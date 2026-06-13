///|
pub fn build_models_url_candidates(
  base_url : String,
  is_full_url : Bool,
  models_url_override : String?,
) -> Result[Array[String], String] {
  match models_url_override {
    Some(raw) => {
      let trimmed = raw.trim().to_owned()
      if !trimmed.is_empty() {
        return Ok([trimmed])
      }
    }
    None => ()
  }

  let trimmed = trim_end_slashes(base_url.trim().to_owned())
  if trimmed.is_empty() {
    return Err("Base URL is empty")
  }

  let candidates : Array[String] = []
  if is_full_url {
    match trimmed.find("/v1/") {
      Some(index) => candidates.push("\{trimmed[:index].to_owned()}/v1/models")
      None =>
        match trimmed.rev_find("/") {
          Some(index) => {
            let root = trimmed[:index].to_owned()
            if root.contains("://") {
              let scheme = root.find("://").unwrap()
              if root.length() > scheme + 3 {
                candidates.push("\{root}/v1/models")
              }
            }
          }
          None => ()
        }
    }
    if candidates.is_empty() {
      return Err("Cannot derive models endpoint from full URL")
    }
    return Ok(candidates)
  }

  if ends_with_version_segment(trimmed) {
    candidates.push("\{trimmed}/models")
    if !trimmed.has_suffix("/v1") {
      candidates.push("\{trimmed}/v1/models")
    }
  } else {
    candidates.push("\{trimmed}/v1/models")
  }

  match strip_compat_suffix(trimmed) {
    Some(stripped) => {
      let root = trim_end_slashes(stripped)
      if !root.is_empty() && root.contains("://") {
        candidates.push("\{root}/v1/models")
        candidates.push("\{root}/models")
      }
    }
    None => ()
  }

  Ok(unique_strings(candidates))
}

///|
fn strip_compat_suffix(base_url : String) -> String? {
  for
    suffix in [
      "/api/claudecode", "/api/anthropic", "/apps/anthropic", "/api/coding", "/claudecode",
      "/anthropic", "/step_plan", "/coding", "/claude",
    ] {
    if base_url.has_suffix(suffix) {
      return Some(base_url[:base_url.length() - suffix.length()].to_owned())
    }
  }
  None
}

///|
fn ends_with_version_segment(url : String) -> Bool {
  let last = match url.rev_find("/") {
    Some(index) => url[index + 1:].to_owned()
    None => url
  }
  if !last.has_prefix("v") || last.length() <= 1 {
    return false
  }
  for c in last[1:] {
    if !c.is_ascii_digit() {
      return false
    }
  }
  true
}

///|
fn unique_strings(values : Array[String]) -> Array[String] {
  let unique : Array[String] = []
  for value in values {
    let mut seen = false
    for existing in unique {
      if existing == value {
        seen = true
      }
    }
    if !seen {
      unique.push(value)
    }
  }
  unique
}
