///|
const MODEL_FETCH_ERROR_BODY_MAX_CHARS = 512

///|
const CODEX_OAUTH_MODELS_URL = "https://chatgpt.com/backend-api/codex/models?client_version=0.1.0"

///|
pub struct FetchedModel {
  id : String
  owned_by : String?
}

///|
pub fn FetchedModel::to_json(self : FetchedModel) -> Json {
  Json::object({
    "id": Json::string(self.id),
    "ownedBy": match self.owned_by {
      Some(value) => Json::string(value)
      None => Json::null()
    },
  })
}

///|
pub fn fetched_models_to_json(models : Array[FetchedModel]) -> Json {
  Json::array(models.map(fn(model) { model.to_json() }))
}

///|
pub async fn fetch_codex_oauth_models_with_token(
  token : String,
  account_id : String,
) -> Result[Array[FetchedModel], String] {
  if token.trim().is_empty() {
    return Err(
      "Codex OAuth token unavailable: access_token is empty or missing",
    )
  }
  if account_id.trim().is_empty() {
    return Err("No ChatGPT account available")
  }
  let target = match models_url_target(CODEX_OAUTH_MODELS_URL) {
    Ok(target) => target
    Err(err) => return Err(err)
  }
  let headers : Map[String, String] = {
    "Authorization": "Bearer \{token}",
    "Accept": "application/json",
    "originator": "moonstat",
    "chatgpt-account-id": account_id,
  }
  let client = @http.Client::new(target.origin, headers~)
  defer client.close()
  let response = client.get(target.path) catch {
    err => return Err("Request failed: \{err}")
  }
  let body = client.read_all().text()
  if response.code is (200..=299) {
    parse_codex_oauth_models_response_body(body)
  } else {
    Err("HTTP \{response.code}: \{truncate_model_fetch_error_body(body)}")
  }
}

///|
pub async fn fetch_models(
  base_url : String,
  api_key : String,
  is_full_url : Bool,
  models_url_override : String?,
  user_agent : String?,
) -> Result[Array[FetchedModel], String] {
  if api_key.is_empty() {
    return Err("API Key is required to fetch models")
  }
  let candidates = match
    build_models_url_candidates(base_url, is_full_url, models_url_override) {
    Ok(candidates) => candidates
    Err(err) => return Err(err)
  }
  let mut last_err : String? = None
  for url in candidates {
    let target = match models_url_target(url) {
      Ok(target) => target
      Err(err) => return Err(err)
    }
    let headers = model_fetch_headers(api_key, user_agent)
    let client = @http.Client::new(target.origin, headers~)
    defer client.close()
    let response = client.get(target.path) catch {
      err => return Err("Request failed: \{err}")
    }
    let body = client.read_all().text()
    if response.code is (200..=299) {
      match parse_models_response_body(body) {
        Ok(models) => return Ok(models)
        Err(err) => return Err(err)
      }
    } else if response.code == 404 || response.code == 405 {
      last_err = Some(
        "HTTP \{response.code}: \{truncate_model_fetch_error_body(body)}",
      )
    } else {
      return Err(
        "HTTP \{response.code}: \{truncate_model_fetch_error_body(body)}",
      )
    }
  }
  Err("All candidates failed: \{last_err.unwrap_or("no candidates")}")
}

///|
fn model_fetch_headers(
  api_key : String,
  user_agent : String?,
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "Authorization": "Bearer \{api_key}",
    "Accept": "application/json",
  }
  match parse_custom_user_agent(user_agent) {
    Some(value) => headers["User-Agent"] = value
    None => ()
  }
  headers
}

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
priv struct ModelsUrlTarget {
  origin : String
  path : String
}

///|
fn models_url_target(url : String) -> Result[ModelsUrlTarget, String] {
  let (raw_origin, raw_path) = split_origin_and_path(url)
  let (origin, raw_path) = if raw_path.is_empty() {
    match raw_origin.find("?") {
      Some(index) =>
        (raw_origin[:index].to_owned(), "/\{raw_origin[index:].to_owned()}")
      None => (raw_origin, raw_path)
    }
  } else {
    (raw_origin, raw_path)
  }
  if !origin.contains("://") {
    return Err("Invalid models endpoint URL: \{url}")
  }
  let path = if raw_path.is_empty() { "/" } else { raw_path }
  Ok({ origin, path })
}

///|
fn parse_models_response_body(
  body : String,
) -> Result[Array[FetchedModel], String] {
  let parsed = @json.parse(body) catch {
    err => return Err("Failed to parse response: \{err}")
  }
  parse_models_response(parsed)
}

///|
fn parse_models_response(value : Json) -> Result[Array[FetchedModel], String] {
  guard value is Object(obj) else {
    return Err("Failed to parse response: expected object")
  }
  let models : Array[FetchedModel] = []
  match obj.get("data") {
    Some(Array(entries)) =>
      for entry in entries {
        match parse_model_entry(entry) {
          Ok(model) => models.push(model)
          Err(err) => return Err(err)
        }
      }
    Some(_) => return Err("Failed to parse response: data must be an array")
    None => ()
  }
  models.sort_by(fn(left, right) { ascii_lex_compare(left.id, right.id) })
  Ok(models)
}

///|
fn parse_model_entry(entry : Json) -> Result[FetchedModel, String] {
  guard entry is Object(obj) else {
    return Err("Failed to parse response: model entry must be an object")
  }
  let id = match obj.get("id") {
    Some(String(value)) => value
    _ => return Err("Failed to parse response: model id is required")
  }
  let owned_by = match obj.get("owned_by") {
    Some(String(value)) => Some(value)
    Some(Null) | None => None
    _ => return Err("Failed to parse response: owned_by must be a string")
  }
  Ok({ id, owned_by })
}

///|
fn parse_codex_oauth_models_response_body(
  body : String,
) -> Result[Array[FetchedModel], String] {
  let parsed = @json.parse(body) catch {
    err => return Err("Failed to parse response: \{err}")
  }
  Ok(parse_codex_oauth_models_response(parsed))
}

///|
fn parse_codex_oauth_models_response(value : Json) -> Array[FetchedModel] {
  let models : Array[FetchedModel] = []
  match value {
    Array(entries) =>
      for entry in entries {
        push_codex_oauth_model_entry(models, entry, None)
      }
    Object(obj) => {
      match first_codex_oauth_models_array(obj) {
        Some(entries) =>
          for entry in entries {
            push_codex_oauth_model_entry(models, entry, None)
          }
        None => ()
      }
      match obj.get("models") {
        Some(Object(model_map)) =>
          for key in model_map.keys() {
            match model_map.get(key) {
              Some(entry) =>
                push_codex_oauth_model_entry(models, entry, Some(key))
              None => ()
            }
          }
        _ => ()
      }
    }
    _ => ()
  }
  models.sort_by(fn(left, right) { ascii_lex_compare(left.id, right.id) })
  dedupe_fetched_models_by_id(models)
}

///|
fn first_codex_oauth_models_array(obj : Map[String, Json]) -> Array[Json]? {
  for key in ["data", "models", "items"] {
    match obj.get(key) {
      Some(Array(entries)) => return Some(entries)
      _ => ()
    }
  }
  None
}

///|
fn push_codex_oauth_model_entry(
  models : Array[FetchedModel],
  entry : Json,
  fallback_id : String?,
) -> Unit {
  match entry {
    String(value) => {
      let id = value.trim().to_owned()
      if !id.is_empty() {
        models.push({ id, owned_by: Some("Codex") })
      }
    }
    Object(obj) => {
      let id = match
        json_string_from_map_any(obj, ["slug", "id", "model", "name"]) {
        Some(value) => Some(value)
        None =>
          match fallback_id {
            Some(value) => Some(value.trim().to_owned())
            None => None
          }
      }
      match id {
        Some(id) if !id.is_empty() => {
          let owned_by = match
            json_string_from_map_any(obj, [
              "owned_by", "ownedBy", "provider", "vendor", "category", "owner",
            ]) {
            Some(value) => Some(value)
            None => Some("Codex")
          }
          models.push({ id, owned_by })
        }
        _ => ()
      }
    }
    _ =>
      match fallback_id {
        Some(value) => {
          let id = value.trim().to_owned()
          if !id.is_empty() {
            models.push({ id, owned_by: Some("Codex") })
          }
        }
        None => ()
      }
  }
}

///|
fn dedupe_fetched_models_by_id(
  models : Array[FetchedModel],
) -> Array[FetchedModel] {
  let unique : Array[FetchedModel] = []
  for model in models {
    let mut seen = false
    for existing in unique {
      if existing.id == model.id {
        seen = true
      }
    }
    if !seen {
      unique.push(model)
    }
  }
  unique
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

///|
fn truncate_model_fetch_error_body(body : String) -> String {
  if body.length() <= MODEL_FETCH_ERROR_BODY_MAX_CHARS {
    body
  } else {
    body[:MODEL_FETCH_ERROR_BODY_MAX_CHARS].to_owned() + "…"
  }
}
