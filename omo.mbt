///|
fn moon_omo_config_candidates(slim : Bool) -> Array[String] {
  let dir = moon_config_dir("opencode")
  if slim {
    [
      @pathx.join(dir, "oh-my-opencode-slim.jsonc"),
      @pathx.join(dir, "oh-my-opencode-slim.json"),
    ]
  } else {
    [
      @pathx.join(dir, "oh-my-openagent.jsonc"),
      @pathx.join(dir, "oh-my-openagent.json"),
      @pathx.join(dir, "oh-my-opencode.jsonc"),
      @pathx.join(dir, "oh-my-opencode.json"),
    ]
  }
}

///|
fn moon_omo_category(slim : Bool) -> String {
  if slim {
    "omo-slim"
  } else {
    "omo"
  }
}

///|
async fn moon_omo_existing_config_path(slim : Bool) -> String? {
  for path in moon_omo_config_candidates(slim) {
    if @fsx.exists(path) {
      return Some(path)
    }
  }
  None
}

///|
async fn moon_read_omo_local_file_json(slim : Bool) -> (Json?, String?) {
  guard moon_omo_existing_config_path(slim) is Some(path) else {
    return (None, Some("OMO 配置文件不存在"))
  }
  let content = @fsx.read_file(path) catch {
    err => return (None, Some("IO 错误: \{path}: \{err}"))
  }
  match
    moon_omo_local_file_data_json_from_content(
      slim,
      path,
      moon_omo_last_modified_json(path),
      content,
    ) {
    Some(data) => (Some(data), None)
    None => (None, Some("Expected JSON object"))
  }
}

///|
fn moon_omo_last_modified_json(path : String) -> Json {
  let stat = @fsx.stat(path) catch { _ => return Json::null() }
  Json::string(@os.local_rfc3339(stat.mtime()))
}

///|
fn moon_omo_local_file_data_json_from_content(
  slim : Bool,
  path : String,
  last_modified : Json,
  content : String,
) -> Json? {
  let cleaned = moon_omo_strip_jsonc_comments(content)
  let parsed = @json.parse(cleaned) catch { _ => return None }
  guard parsed is Object(obj) else { return None }
  Some(moon_omo_local_file_data_json(slim, obj, path, last_modified))
}

///|
fn moon_omo_local_file_data_json(
  slim : Bool,
  obj : Map[String, Json],
  path : String,
  last_modified : Json,
) -> Json {
  let other : Map[String, Json] = {}
  for key in obj.keys() {
    if key != "agents" && key != "categories" {
      guard obj.get(key) is Some(value) else { continue }
      other[key] = value
    }
  }
  {
    "agents": obj.get("agents").unwrap_or(Json::null()),
    "categories": if slim {
      Json::null()
    } else {
      obj.get("categories").unwrap_or(Json::null())
    },
    "otherFields": if other.is_empty() {
      Json::null()
    } else {
      Json::object(other)
    },
    "filePath": Json::string(path),
    "lastModified": last_modified,
  }.to_json()
}

///|
fn moon_omo_strip_jsonc_comments(input : String) -> String {
  let chars = input.to_array()
  let out = StringBuilder::new()
  let mut i = 0
  let mut in_string = false
  let mut escaped = false
  while i < chars.length() {
    let ch = chars[i]
    if in_string {
      out.write_char(ch)
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch == '"' {
        in_string = false
      }
      i += 1
      continue
    }
    if ch == '"' {
      in_string = true
      out.write_char(ch)
      i += 1
      continue
    }
    if ch == '/' && i + 1 < chars.length() && chars[i + 1] == '/' {
      i += 2
      while i < chars.length() && chars[i] != '\n' {
        i += 1
      }
      if i < chars.length() {
        out.write_char(chars[i])
        i += 1
      }
      continue
    }
    if ch == '/' && i + 1 < chars.length() && chars[i + 1] == '*' {
      i += 2
      while i + 1 < chars.length() && !(chars[i] == '*' && chars[i + 1] == '/') {
        i += 1
      }
      if i + 1 < chars.length() {
        i += 2
      }
      continue
    }
    out.write_char(ch)
    i += 1
  }
  out.to_string()
}

///|
fn ProxyService::current_omo_provider_id(
  self : ProxyService,
  slim : Bool,
) -> String {
  let category = moon_omo_category(slim)
  let current = self.provider_router
    .current_provider_id("opencode")
    .unwrap_or("")
  guard self.provider_router.provider_by_id("opencode", current)
    is Some(provider) else {
    return ""
  }
  if provider.provider_type == Some(category) {
    current
  } else {
    ""
  }
}

///|
fn ProxyService::clear_current_omo_provider(
  self : ProxyService,
  slim : Bool,
) -> Unit {
  let category = moon_omo_category(slim)
  let current = self.provider_router
    .current_provider_id("opencode")
    .unwrap_or("")
  guard self.provider_router.provider_by_id("opencode", current)
    is Some(provider) else {
    return
  }
  if provider.provider_type == Some(category) {
    self.provider_router.current_provider_ids.remove("opencode")
  }
}

///|
async fn moon_delete_omo_config_files(slim : Bool) -> String? {
  for path in moon_omo_config_candidates(slim) {
    if @fsx.exists(path) {
      @fsx.remove(path) catch {
        err => return Some("IO 错误: \{path}: \{err}")
      }
    }
  }
  None
}
