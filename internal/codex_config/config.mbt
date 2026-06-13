///|
const PROVIDER_ID = "moonstat"

///|
const START_MARKER = "# >>> moonstat managed codex proxy"

///|
const END_MARKER = "# <<< moonstat managed codex proxy"

///|
const CONFIG_FILE = "config.toml"

///|
const MODEL_CATALOG_FILE = "moonstat-model-catalog.json"

///|
pub struct CodexConfigInstall {
  config_path : String
  model_catalog_path : String
  base_url : String
  model : String
}

///|
pub struct CodexConfigStatus {
  configured : Bool
  config_path : String
  model_catalog_path : String
  base_url : String?
  model : String?
}

///|
pub async fn install_proxy_config(
  host : String,
  port : Int,
  model : String,
) -> Result[CodexConfigInstall, String] {
  install_proxy_config_at(home_dir(), host, port, model)
}

///|
async fn install_proxy_config_at(
  home : String,
  host : String,
  port : Int,
  model : String,
) -> Result[CodexConfigInstall, String] {
  let path = codex_config_path_at(home)
  let catalog_path = codex_model_catalog_path_at(home)
  let base_url = local_codex_base_url(host, port)
  let model = normalized_model(model)
  try {
    let existing = read_file_or_empty(path)
    let content = append_managed_block(
      remove_managed_block(existing),
      managed_block(base_url, model),
    )
    @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
    overwrite_config_file(
      catalog_path,
      codex_model_catalog_json(model).stringify(),
    )
    overwrite_config_file(path, content)
    Ok({ config_path: path, model_catalog_path: catalog_path, base_url, model })
  } catch {
    err => Err("failed to install Codex proxy config: \{err}")
  }
}

///|
pub async fn uninstall_proxy_config() -> Result[Unit, String] {
  uninstall_proxy_config_at(home_dir())
}

///|
async fn uninstall_proxy_config_at(home : String) -> Result[Unit, String] {
  let path = codex_config_path_at(home)
  try {
    if @fsx.exists_as_file(path) {
      let content = remove_managed_block(@fsx.read_file(path))
      overwrite_config_file(path, normalize_final_newline(content))
    }
    @fsx.remove(codex_model_catalog_path_at(home)) catch {
      _ => ()
    }
    Ok(())
  } catch {
    err => Err("failed to uninstall Codex proxy config: \{err}")
  }
}

///|
pub async fn status() -> CodexConfigStatus {
  status_at(home_dir())
}

///|
async fn status_at(home : String) -> CodexConfigStatus {
  let path = codex_config_path_at(home)
  let content = read_file_or_empty(path)
  {
    configured: contains_managed_block(content),
    config_path: path,
    model_catalog_path: codex_model_catalog_path_at(home),
    base_url: managed_string_value(content, "base_url"),
    model: managed_string_value(content, "model"),
  }
}

///|
pub async fn active_model_catalog_json() -> Json? {
  active_model_catalog_json_at(home_dir())
}

///|
async fn active_model_catalog_json_at(home : String) -> Json? {
  let config = read_file_or_empty(codex_config_path_at(home))
  guard contains_managed_block(config) else { return None }
  guard managed_string_value(config, "model_catalog_json") is Some(raw_path) else {
    return None
  }
  guard resolve_model_catalog_path(home, raw_path) ==
    codex_model_catalog_path_at(home) else {
    return None
  }
  let catalog_path = codex_model_catalog_path_at(home)
  if !@fsx.exists_as_file(catalog_path) {
    return Some(empty_model_catalog_json())
  }
  Some(
    @json.parse(@fsx.read_file(catalog_path)) catch {
      _ => empty_model_catalog_json()
    },
  )
}

///|
async fn overwrite_config_file(path : String, content : String) -> Unit {
  @fsx.remove(path) catch {
    _ => ()
  }
  @fsx.write_to_file(path, content, create=0o600)
}

///|
fn codex_config_path_at(home : String) -> String {
  @pathx.join(@pathx.join(home, ".codex"), CONFIG_FILE)
}

///|
fn codex_model_catalog_path_at(home : String) -> String {
  @pathx.join(@pathx.join(home, ".codex"), MODEL_CATALOG_FILE)
}

///|
fn resolve_model_catalog_path(home : String, raw_path : String) -> String {
  let value = raw_path.trim()
  if value == MODEL_CATALOG_FILE {
    codex_model_catalog_path_at(home)
  } else {
    value.to_owned()
  }
}

///|
fn home_dir() -> String {
  @os.home() catch {
    _ => "."
  }
}

///|
fn local_codex_base_url(host : String, port : Int) -> String {
  let host = if host == "0.0.0.0" || host == "::" { "127.0.0.1" } else { host }
  "http://\{host}:\{port}/v1"
}

///|
fn normalized_model(model : String) -> String {
  let trimmed = model.trim().to_owned()
  if trimmed.is_empty() {
    "gpt-5"
  } else {
    trimmed
  }
}

///|
fn managed_block(base_url : String, model : String) -> String {
  "\{START_MARKER}\n" +
  "model = \"\{model}\"\n" +
  "model_provider = \"\{PROVIDER_ID}\"\n" +
  "model_catalog_json = \"\{MODEL_CATALOG_FILE}\"\n" +
  "\n" +
  "[model_providers.\{PROVIDER_ID}]\n" +
  "name = \"Moonstat\"\n" +
  "base_url = \"\{base_url}\"\n" +
  "wire_api = \"responses\"\n" +
  "experimental_bearer_token = \"moonstat-local-proxy\"\n" +
  END_MARKER
}

///|
fn empty_model_catalog_json() -> Json {
  { "models": Json::array([]) }.to_json()
}

///|
fn codex_model_catalog_json(model : String) -> Json {
  { "models": Json::array([codex_model_catalog_entry_json(model)]) }.to_json()
}

///|
fn codex_model_catalog_entry_json(model : String) -> Json {
  {
    "slug": Json::string(model),
    "display_name": Json::string(model),
    "description": Json::string("Moonstat local proxy model"),
    "visibility": Json::string("list"),
    "supported_in_api": Json::boolean(true),
    "priority": Json::number(1000.0),
    "context_window": Json::number(128000.0),
    "max_context_window": Json::number(128000.0),
    "additional_speed_tiers": Json::array([]),
    "service_tiers": Json::array([]),
    "availability_nux": Json::null(),
    "upgrade": Json::null(),
    "base_instructions": Json::string(""),
    "model_messages": {
      "instructions_template": Json::string(""),
      "instructions_variables": {
        "personality_default": Json::string(""),
        "personality_friendly": Json::string(""),
        "personality_pragmatic": Json::string(""),
      }.to_json(),
    }.to_json(),
  }.to_json()
}

///|
fn contains_managed_block(content : String) -> Bool {
  content.find(START_MARKER) is Some(_) && content.find(END_MARKER) is Some(_)
}

///|
fn remove_managed_block(content : String) -> String {
  guard content.find(START_MARKER) is Some(start) else { return content }
  let tail = content[start:]
  guard tail.find(END_MARKER) is Some(end_rel) else { return content }
  let end = start + end_rel + END_MARKER.length()
  let before = content[:start].to_owned()
  let after = if end < content.length() {
    let rest = content[end:]
    if rest.has_prefix("\n") {
      rest[1:].to_owned()
    } else {
      rest.to_owned()
    }
  } else {
    ""
  }
  join_after_remove(before, after)
}

///|
fn join_after_remove(before : String, after : String) -> String {
  let before = before.trim_end().to_owned()
  let after = after.trim_start().to_owned()
  if before.is_empty() {
    after
  } else if after.is_empty() {
    before
  } else {
    "\{before}\n\n\{after}"
  }
}

///|
fn append_managed_block(content : String, block : String) -> String {
  let content = content.trim_end().to_owned()
  if content.is_empty() {
    "\{block}\n"
  } else {
    "\{content}\n\n\{block}\n"
  }
}

///|
fn normalize_final_newline(content : String) -> String {
  let content = content.trim_end().to_owned()
  if content.is_empty() {
    ""
  } else {
    "\{content}\n"
  }
}

///|
async fn read_file_or_empty(path : String) -> String {
  if @fsx.exists_as_file(path) {
    @fsx.read_file(path) catch {
      _ => ""
    }
  } else {
    ""
  }
}

///|
fn managed_string_value(content : String, key : String) -> String? {
  guard content.find(START_MARKER) is Some(start) else { return None }
  let tail = content[start:]
  guard tail.find(END_MARKER) is Some(end_rel) else { return None }
  let block = tail[:end_rel].to_owned()
  let prefix = "\{key} = \""
  for line in block.split("\n") {
    let line = line.trim()
    if line.has_prefix(prefix) && line.has_suffix("\"") {
      return Some(line[prefix.length():line.length() - 1].to_owned())
    }
  }
  None
}
