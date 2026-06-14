///|
const ONE_M_CONTEXT_MARKER = "[1M]"

///|
pub struct ModelMapping {
  haiku_model : String?
  sonnet_model : String?
  opus_model : String?
  default_model : String?
}

///|
pub fn ModelMapping::new(
  haiku_model? : String? = None,
  sonnet_model? : String? = None,
  opus_model? : String? = None,
  default_model? : String? = None,
) -> ModelMapping {
  {
    haiku_model: clean_model_mapping_value(haiku_model),
    sonnet_model: clean_model_mapping_value(sonnet_model),
    opus_model: clean_model_mapping_value(opus_model),
    default_model: clean_model_mapping_value(default_model),
  }
}

///|
pub fn ModelMapping::has_mapping(self : ModelMapping) -> Bool {
  self.haiku_model is Some(_) ||
  self.sonnet_model is Some(_) ||
  self.opus_model is Some(_) ||
  self.default_model is Some(_)
}

///|
pub fn ModelMapping::map_model(
  self : ModelMapping,
  original_model : String,
) -> String {
  let model_lower = original_model.to_lower()
  if model_lower.contains("haiku") {
    if self.haiku_model is Some(model) {
      return model
    }
  }
  if model_lower.contains("opus") {
    if self.opus_model is Some(model) {
      return model
    }
  }
  if model_lower.contains("sonnet") {
    if self.sonnet_model is Some(model) {
      return model
    }
  }
  match self.default_model {
    Some(model) => model
    None => original_model
  }
}

///|
pub fn ModelMapping::to_json(self : ModelMapping) -> Json {
  {
    "haikuModel": optional_model_mapping_string_json(self.haiku_model),
    "sonnetModel": optional_model_mapping_string_json(self.sonnet_model),
    "opusModel": optional_model_mapping_string_json(self.opus_model),
    "defaultModel": optional_model_mapping_string_json(self.default_model),
  }.to_json()
}

///|
pub fn ProviderRouteTarget::map_model_for_upstream(
  self : ProviderRouteTarget,
  original_model : String,
) -> String {
  let mapped = match self.model_mapping {
    Some(mapping) if mapping.has_mapping() => mapping.map_model(original_model)
    _ => original_model
  }
  if self.is_github_copilot_upstream() {
    match copilot_normalize_to_upstream_id(mapped) {
      Some(normalized) => normalized
      None => mapped
    }
  } else {
    strip_one_m_suffix_for_upstream(mapped)
  }
}

///|
pub fn strip_one_m_suffix_for_upstream(model : String) -> String {
  let trimmed = model.trim_end().to_owned()
  if trimmed.length() < ONE_M_CONTEXT_MARKER.length() {
    return model
  }
  let start = trimmed.length() - ONE_M_CONTEXT_MARKER.length()
  let suffix = trimmed[start:].to_owned()
  if suffix.to_lower() == ONE_M_CONTEXT_MARKER.to_lower() {
    trimmed[:start].to_owned().trim_end().to_owned()
  } else {
    model
  }
}

///|
fn clean_model_mapping_value(value : String?) -> String? {
  match value {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed.is_empty() {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn optional_model_mapping_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn ProviderRouteTarget::is_github_copilot_upstream(
  self : ProviderRouteTarget,
) -> Bool {
  if self.provider_type == Some("github_copilot") {
    return true
  }
  match self.base_url {
    Some(base_url) => base_url.to_lower().contains("githubcopilot.com")
    None => false
  }
}

///|
pub fn copilot_normalize_to_upstream_id(client_id : String) -> String? {
  let trimmed = client_id.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed.length() < 8 || !lower.has_prefix("claude-") {
    return None
  }
  let has_one_m_bracket = lower.has_suffix("[1m]")
  if trimmed.contains(".") && !has_one_m_bracket {
    return None
  }
  let (base, has_one_m_suffix) = copilot_split_one_m_suffix(trimmed)
  let stripped = copilot_strip_trailing_date(base)
  let mut candidate = match copilot_dashes_to_dot_in_last_version(stripped) {
    Some(dotted) => dotted
    None => {
      if !has_one_m_suffix {
        return None
      }
      stripped
    }
  }
  if has_one_m_suffix {
    candidate = "\{candidate}-1m"
  }
  if candidate == client_id {
    None
  } else {
    Some(candidate)
  }
}

///|
pub fn copilot_resolve_against_model_ids(
  client_id : String,
  model_ids : Array[String],
) -> String? {
  let normalized = copilot_normalize_to_upstream_id(client_id)
  let target = match normalized {
    Some(value) => value
    None => client_id
  }
  let target_lower = target.to_lower()
  if model_ids.any(fn(model_id) { model_id.to_lower() == target_lower }) {
    return match normalized {
      Some(value) if value != client_id => Some(value)
      _ => None
    }
  }
  match copilot_family_fallback(target, model_ids) {
    Some(fallback) if fallback.to_lower() != client_id.to_lower() =>
      Some(fallback)
    _ => None
  }
}

///|
pub fn copilot_resolve_against_models_json(
  client_id : String,
  models_json : Json,
) -> String? {
  copilot_resolve_against_model_ids(
    client_id,
    copilot_model_ids_from_models_json(models_json),
  )
}

///|
pub fn copilot_model_ids_from_models_json(models_json : Json) -> Array[String] {
  let items = match models_json {
    Array(items) => items
    Object(obj) =>
      match obj.get("data") {
        Some(Array(items)) => items
        _ => []
      }
    _ => []
  }
  let ids : Array[String] = []
  for item in items {
    guard item is Object(model_obj) else { continue }
    if !copilot_model_picker_enabled(model_obj) {
      continue
    }
    match copilot_json_string_value(model_obj, "id") {
      Some(id) if !id.trim().is_empty() => ids.push(id)
      _ => ()
    }
  }
  ids
}

///|
fn copilot_model_picker_enabled(model_obj : Map[String, Json]) -> Bool {
  match model_obj.get("model_picker_enabled") {
    Some(False) => false
    Some(True) => true
    _ => true
  }
}

///|
fn copilot_json_string_value(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn copilot_split_one_m_suffix(id : String) -> (String, Bool) {
  let lower = id.to_lower()
  if lower.has_suffix("[1m]") {
    (id[:id.length() - 4].to_owned(), true)
  } else if lower.has_suffix("-1m") {
    (id[:id.length() - 3].to_owned(), true)
  } else {
    (id, false)
  }
}

///|
fn copilot_strip_trailing_date(id : String) -> String {
  let parts = id.split("-").collect()
  if parts.length() < 2 {
    return id
  }
  let last = parts[parts.length() - 1].to_owned()
  if last.length() != 8 || !copilot_ascii_digits(last) {
    return id
  }
  let kept : Array[String] = []
  for index in 0..<(parts.length() - 1) {
    kept.push(parts[index].to_owned())
  }
  kept.join("-")
}

///|
fn copilot_dashes_to_dot_in_last_version(id : String) -> String? {
  let parts = id.split("-").collect()
  if parts.length() < 3 {
    return None
  }
  let last = parts[parts.length() - 1].to_owned()
  let previous = parts[parts.length() - 2].to_owned()
  if !copilot_ascii_digits(last) || !copilot_ascii_digits(previous) {
    return None
  }
  let head : Array[String] = []
  for index in 0..<(parts.length() - 1) {
    head.push(parts[index].to_owned())
  }
  Some("\{head.join("-")}.\{last}")
}

///|
fn copilot_ascii_digits(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for ch in value {
    let code = ch.to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      return false
    }
  }
  true
}

///|
fn copilot_family_fallback(
  target : String,
  model_ids : Array[String],
) -> String? {
  guard copilot_detect_family(target) is Some(family) else { return None }
  let want_one_m = target.to_lower().has_suffix("-1m")
  if want_one_m {
    match
      copilot_pick_best_family_model(family, model_ids, require_one_m=true) {
      Some(model) => return Some(model)
      None => ()
    }
  }
  copilot_pick_best_family_model(family, model_ids, require_one_m=false)
}

///|
fn copilot_pick_best_family_model(
  family : String,
  model_ids : Array[String],
  require_one_m~ : Bool,
) -> String? {
  let mut best : String? = None
  let mut best_major = -1
  let mut best_minor = -1
  for model_id in model_ids {
    let lower = model_id.to_lower()
    if !lower.contains(family) || lower.has_suffix("-1m") != require_one_m {
      continue
    }
    match copilot_extract_major_minor(model_id) {
      Some((major, minor)) =>
        if major > best_major || (major == best_major && minor > best_minor) {
          best = Some(model_id)
          best_major = major
          best_minor = minor
        }
      None => ()
    }
  }
  best
}

///|
fn copilot_detect_family(id : String) -> String? {
  let lower = id.to_lower()
  if lower.contains("haiku") {
    Some("haiku")
  } else if lower.contains("sonnet") {
    Some("sonnet")
  } else if lower.contains("opus") {
    Some("opus")
  } else {
    None
  }
}

///|
fn copilot_extract_major_minor(id : String) -> (Int, Int)? {
  let lower = id.to_lower()
  guard copilot_detect_family(lower) is Some(family) else { return None }
  guard lower.find(family) is Some(index) else { return None }
  let after_family = lower[index + family.length():].to_owned()
  if !after_family.has_prefix("-") {
    return None
  }
  let after_dash = after_family[1:].to_owned()
  let segment = copilot_model_version_segment(after_dash)
  let parts = segment.split(".").collect()
  if parts.length() == 0 {
    return None
  }
  let major = @string.parse_int(parts[0].to_owned(), base=10) catch {
    _ => return None
  }
  let minor = if parts.length() > 1 {
    @string.parse_int(parts[1].to_owned(), base=10) catch {
      _ => return None
    }
  } else {
    0
  }
  Some((major, minor))
}

///|
fn copilot_model_version_segment(value : String) -> String {
  let mut end = value.length()
  for separator in ["-", "[", " "] {
    match value.find(separator) {
      Some(index) if index < end => end = index
      _ => ()
    }
  }
  value[:end].to_owned()
}
